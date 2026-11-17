import 'dart:convert';

import 'package:at_primitives/tid.dart' show isValidTid;
import 'package:atproto_core/atproto_core.dart' show AtUri;
import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../storage/local_database.dart';
import '../drafts/draft.dart';
import '../instagram/instagram_package.dart';
import '../instagram/instagram_service.dart' show samePackageSource;
import '../review/review.dart';
import 'attempt.dart';

/// A valid provider receipt survived in memory, but its durable write failed.
/// Its identifier is only a reconciliation hint until exact publication checks.
class UnrecordedReceipt implements Exception {
  const UnrecordedReceipt(this.remoteId);
  final String remoteId;
  @override
  String toString() =>
      'The provider receipt could not be recorded. Check publication before retrying.';
}

bool ordinaryRetryAllowed(PublishOutcome outcome) =>
    outcome.status == PublishStatus.notPublished ||
    outcome.status == PublishStatus.connectionNeeded;

/// The SQLite row is a materialized projection; direct evidence is append-only.
/// A retry is a new leaf with no upload/dispatch state from its parent.
class AttemptRepository {
  AttemptRepository(this.database, this.clock, this.ids);
  final LocalDatabase database;
  final Clock clock;
  final Ids ids;

  PublishOutcome _local(PublishStatus status, String reason, String message) =>
      PublishOutcome(
        status: status,
        source: EvidenceSource.local,
        at: clock.now(),
        reasonCode: reason,
        message: message,
      );

  Future<AttemptGroup?> findExisting(
    ReviewedPost reviewed,
    String operationId,
  ) => _existing(database.db, reviewed, operationId);

  Future<AttemptGroup?> _existing(
    DatabaseExecutor tx,
    ReviewedPost reviewed,
    String operationId,
  ) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    final operations = await tx.query(
      'attempt_groups',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
    if (operations.isNotEmpty) {
      final group = _group(operations.single);
      if (group.snapshot.draftId != reviewed.draftId) {
        throw StateError('This operation belongs to another review.');
      }
      return group;
    }
    final revisions = await tx.query(
      'attempt_groups',
      where: 'draft_id = ?',
      whereArgs: [reviewed.draftId],
    );
    return revisions.isEmpty ? null : _group(revisions.single);
  }

  Future<({AttemptGroup group, bool created})> begin(
    ReviewedPost reviewed,
    String operationId,
  ) => database.db.transaction((tx) async {
    final existing = await _existing(tx, reviewed, operationId);
    if (existing != null) return (group: existing, created: false);
    await _requireSavedRevision(tx, reviewed);
    if (reviewed.draftId.isEmpty ||
        reviewed.revision < 0 ||
        reviewed.posts.isEmpty ||
        reviewed.posts.entries.any(
          (e) =>
              e.key != e.value.destination ||
              reviewed.capabilityVersions[e.key]?.isNotEmpty != true,
        )) {
      throw ArgumentError('Incomplete reviewed source.');
    }
    final group = AttemptGroup(
      id: ids.next(),
      snapshot: reviewed,
      operationId: operationId,
      createdAt: clock.now(),
    );
    await tx.insert('attempt_groups', {
      'id': group.id,
      'draft_id': reviewed.draftId,
      'revision': reviewed.revision,
      'operation_id': operationId,
      'payload': jsonEncode(group.toJson()),
      'instagram_state': reviewed.posts.containsKey(Destination.instagram)
          ? 'pending'
          : null,
    });
    for (final post in reviewed.posts.values.where(
      (p) => p.destination != Destination.instagram,
    )) {
      final attempt = DestinationAttempt(
        id: ids.next(),
        groupId: group.id,
        snapshot: post,
        outcome: _local(
          PublishStatus.pending,
          'not-sent',
          'Not sent — continue when ready',
        ),
        uploadState: {},
      );
      await tx.insert('destination_attempts', _row(attempt));
      await _event(tx, attempt, 'begun');
    }
    return (group: group, created: true);
  });

  /// Submitted drafts always reopen their immutable result, across later edits.
  Future<AttemptGroup?> getGroupForDraft(String draftId) async {
    final rows = await database.db.query(
      'attempt_groups',
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
    return rows.isEmpty ? null : _group(rows.single);
  }

  Future<AttemptGroup?> getGroup(String id) async {
    final rows = await database.db.query(
      'attempt_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _group(rows.single);
  }

  Future<DestinationAttempt?> getAttempt(String id) => _get(database.db, id);
  Future<DestinationAttempt?> _get(DatabaseExecutor tx, String id) async {
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _attempt(rows.single);
  }

  Future<List<DestinationAttempt>> attempts(String groupId) async =>
      (await database.db.query(
        'destination_attempts',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'rowid',
      )).map(_attempt).toList();

  /// Completion evidence wins over a later failed/pending recovery child.
  /// The returned attempt carries the actual winning frozen source.
  Future<List<DestinationAttempt>> effectiveAttempts(String groupId) async {
    final history = await attempts(groupId);
    final effective = <DestinationAttempt>[];
    for (final destination in [Destination.x, Destination.bluesky]) {
      final chain = history
          .where((a) => a.snapshot.destination == destination)
          .toList();
      if (chain.isEmpty) continue;
      effective.add(
        chain
                .where((a) => a.outcome.status == PublishStatus.published)
                .firstOrNull ??
            chain
                .where((a) => a.outcome.status == PublishStatus.userReported)
                .firstOrNull ??
            chain.last,
      );
    }
    return effective;
  }

  Future<ReviewedPost> reviewForAttempt(String id) async {
    final rows = await database.db.query(
      'destination_attempts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Attempt unavailable.');
    final attempt = _attempt(rows.single);
    final group = await getGroup(attempt.groupId);
    if (group == null) throw StateError('Review unavailable.');
    if (attempt.parentId != null) {
      final parent = await getAttempt(attempt.parentId!);
      if (parent == null ||
          parent.groupId != attempt.groupId ||
          parent.snapshot.destination != attempt.snapshot.destination) {
        throw const FormatException('Child source disagrees with its parent.');
      }
    }
    final stored = rows.single['review_payload'];
    final review = stored == null
        ? group.snapshot
        : ReviewedPost.fromJson(
            jsonDecode(stored as String) as Map<String, dynamic>,
          );
    if (review.draftId != group.snapshot.draftId ||
        review.posts[attempt.snapshot.destination] != attempt.snapshot ||
        review.capabilityVersions[attempt.snapshot.destination]?.isNotEmpty !=
            true ||
        (attempt.parentId != null && review.posts.length != 1)) {
      throw const FormatException('Attempt source disagrees with its review.');
    }
    return _scope(review, attempt.snapshot.destination);
  }

  Future<bool> claim(String id) => database.db.transaction((tx) async {
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ? AND busy = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) return false;
    final current = _attempt(rows.single);
    if (current.dispatchAt != null ||
        !(current.outcome.status == PublishStatus.pending ||
            current.outcome.status == PublishStatus.processing &&
                current.outcome.reasonCode == 'preparation-ready')) {
      return false;
    }
    if (await _destinationCompleted(tx, current)) return false;
    final next = current.copyWith(
      outcome: _local(
        PublishStatus.preparing,
        'preparing',
        'Preparing this reviewed version.',
      ),
    );
    final changed = await tx.update(
      'destination_attempts',
      {..._row(next), 'busy': 1},
      where: 'id = ? AND busy = 0 AND state = ?',
      whereArgs: [id, current.outcome.status.name],
    );
    if (changed == 1) await _event(tx, next, 'claimed');
    return changed == 1;
  });

  /// Check keeps prior evidence visible while excluding simultaneous send/check.
  Future<bool> claimCheck(String id) => database.db.transaction((tx) async {
    final current = await _get(tx, id);
    if (current == null ||
        !{
          PublishStatus.unknown,
          PublishStatus.processing,
        }.contains(current.outcome.status)) {
      return false;
    }
    return await tx.update(
          'destination_attempts',
          {'busy': 1},
          where: 'id = ? AND busy = 0',
          whereArgs: [id],
        ) ==
        1;
  });

  Future<void> markDispatch(String id) => database.db.transaction((tx) async {
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ? AND busy = 1',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('No exclusive publication claim.');
    final current = _attempt(rows.single);
    if (current.outcome.status != PublishStatus.preparing ||
        current.dispatchAt != null) {
      throw StateError('Create was already dispatched or is not claimed.');
    }
    if (await _destinationCompleted(tx, current)) {
      throw StateError(
        'This destination already has completed publication evidence. Start a new draft to publish again.',
      );
    }
    final next = current.copyWith(
      dispatchAt: clock.now(),
      outcome: _local(
        PublishStatus.sending,
        'create-dispatched',
        'Publication response is pending.',
      ),
    );
    await _write(tx, next, 'dispatched');
  });

  Future<void> saveUpload(String id, String key, String value) =>
      database.db.transaction((tx) async {
        if (key.isEmpty) throw ArgumentError.value(key, 'key');
        final current = await _claimed(tx, id);
        if ({
          PublishStatus.published,
          PublishStatus.userReported,
        }.contains(current.outcome.status)) {
          throw StateError('Completed attempts are immutable.');
        }
        final next = current.copyWith(
          uploadState: {...current.uploadState, key: value},
        );
        await _write(tx, next, 'upload-saved');
      });

  Future<void> record(String id, PublishOutcome outcome) async {
    String? validatedRemoteId;
    try {
      await database.db.transaction((tx) async {
        final current = await _claimed(tx, id);
        if ({
              PublishStatus.pending,
              PublishStatus.preparing,
              PublishStatus.sending,
              PublishStatus.userReported,
            }.contains(outcome.status) ||
            outcome.source == EvidenceSource.user) {
          throw ArgumentError('This is not provider publication evidence.');
        }
        if ({
          PublishStatus.published,
          PublishStatus.userReported,
          PublishStatus.notPublished,
          PublishStatus.connectionNeeded,
        }.contains(current.outcome.status)) {
          throw StateError('Completed outcomes are immutable.');
        }
        if (current.outcome.status == PublishStatus.unknown &&
            outcome.status != PublishStatus.unknown &&
            outcome.status != PublishStatus.published) {
          throw ArgumentError('A failed check cannot prove nonpublication.');
        }
        if (outcome.status == PublishStatus.published) {
          _validateReceipt(current, outcome);
          validatedRemoteId = outcome.remoteId;
        }
        if (current.dispatchAt != null &&
            outcome.status == PublishStatus.processing) {
          throw ArgumentError(
            'Dispatched publication cannot resume preparation.',
          );
        }
        await _write(
          tx,
          current.copyWith(outcome: outcome),
          'outcome',
          busy: 0,
        );
      });
    } catch (_) {
      if (validatedRemoteId != null) {
        throw UnrecordedReceipt(validatedRemoteId!);
      }
      rethrow;
    }
  }

  Future<DestinationAttempt> _claimed(DatabaseExecutor tx, String id) async {
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ? AND busy = 1',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('No exclusive attempt claim.');
    return _attempt(rows.single);
  }

  Future<({DestinationAttempt attempt, bool created})> createChild(
    String parentId,
    ReviewedPost reviewed,
    String operationId, {
    bool allowUnknown = false,
  }) => database.db.transaction((tx) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    final prior = await tx.query(
      'destination_attempts',
      where: 'retry_operation = ?',
      whereArgs: [operationId],
    );
    if (prior.isNotEmpty) {
      final child = _attempt(prior.single);
      if (child.parentId != parentId) {
        throw StateError('Retry operation belongs to another attempt.');
      }
      return (attempt: child, created: false);
    }
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ? AND busy = 0',
      whereArgs: [parentId],
    );
    if (rows.isEmpty) throw StateError('Attempt is busy or unavailable.');
    final parent = _attempt(rows.single);
    if (await _destinationCompleted(tx, parent)) {
      throw StateError(
        'This destination already has completed publication evidence. Start a new draft to publish again.',
      );
    }
    if (!(ordinaryRetryAllowed(parent.outcome) ||
        allowUnknown && parent.outcome.status == PublishStatus.unknown)) {
      throw StateError('This outcome cannot be retried.');
    }
    if (parent.outcome.retryAfter != null &&
        clock.now().isBefore(parent.outcome.retryAfter!)) {
      throw StateError('Wait until the provider retry time.');
    }
    if ((await tx.query(
      'destination_attempts',
      columns: ['id'],
      where: 'parent_id = ?',
      whereArgs: [parentId],
    )).isNotEmpty) {
      throw StateError('Continue from the latest destination attempt.');
    }
    final groupRows = await tx.query(
      'attempt_groups',
      where: 'id = ?',
      whereArgs: [parent.groupId],
    );
    final group = _group(groupRows.single);
    final destination = parent.snapshot.destination;
    final snapshot = reviewed.posts[destination];
    if (reviewed.draftId != group.snapshot.draftId ||
        snapshot == null ||
        snapshot.destination != destination ||
        snapshot.account == null ||
        snapshot.account!.destination != destination ||
        snapshot.account!.subject.isEmpty ||
        snapshot.account!.handle.isEmpty ||
        reviewed.capabilityVersions[destination]?.isNotEmpty != true) {
      throw ArgumentError('Retry review does not belong to this destination.');
    }
    await _requireSavedRevision(tx, reviewed);
    final scoped = _scope(reviewed, destination);
    final child = DestinationAttempt(
      id: ids.next(),
      groupId: parent.groupId,
      parentId: parentId,
      snapshot: snapshot,
      outcome: _local(
        PublishStatus.pending,
        'not-sent',
        'Not sent — continue when ready',
      ),
      uploadState: {},
    );
    await tx.insert('destination_attempts', {
      ..._row(child),
      'retry_operation': operationId,
      'review_payload': jsonEncode(scoped.toJson()),
    });
    await _event(tx, child, 'child-begun');
    return (attempt: child, created: true);
  });

  Future<String?> childForOperation(String parentId, String operationId) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    final rows = await database.db.query(
      'destination_attempts',
      where: 'retry_operation = ?',
      whereArgs: [operationId],
    );
    if (rows.isEmpty) return null;
    final child = _attempt(rows.single);
    if (child.parentId != parentId) {
      throw StateError('Retry operation belongs to another attempt.');
    }
    return child.id;
  }

  Future<void> reportFound(String id) => database.db.transaction((tx) async {
    final rows = await tx.query(
      'destination_attempts',
      where: 'id = ? AND busy = 0',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('Attempt is busy or unavailable.');
    final current = _attempt(rows.single);
    if (current.outcome.status != PublishStatus.unknown ||
        (await tx.query(
          'destination_attempts',
          columns: ['id'],
          where: 'parent_id = ?',
          whereArgs: [id],
        )).isNotEmpty) {
      throw StateError('Only an unresolved unknown attempt can be confirmed.');
    }
    await _write(
      tx,
      current.copyWith(
        outcome: PublishOutcome(
          status: PublishStatus.userReported,
          source: EvidenceSource.user,
          at: clock.now(),
          reasonCode: 'user-found',
          message: 'You marked this post as found.',
        ),
      ),
      'user-found',
    );
  });

  Future<InstagramPreparation?> instagramPreparation(String groupId) async {
    final rows = await database.db.query(
      'attempt_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
    if (rows.isEmpty || rows.single['instagram_state'] == null) return null;
    return InstagramPreparation(
      groupId: groupId,
      state: InstagramPreparationState.values.byName(
        rows.single['instagram_state'] as String,
      ),
      packageId: rows.single['instagram_package_id'] as String?,
      reason: rows.single['instagram_reason'] as String?,
    );
  }

  Future<bool> claimInstagram(String groupId) async =>
      await database.db.update(
        'attempt_groups',
        {'instagram_state': 'preparing', 'instagram_reason': null},
        where: "id = ? AND instagram_state IN ('pending', 'failed')",
        whereArgs: [groupId],
      ) ==
      1;
  Future<void> completeInstagram(String groupId, String packageId) =>
      database.db.transaction((tx) async {
        final groups = await tx.query(
          'attempt_groups',
          where: "id = ? AND instagram_state = 'preparing'",
          whereArgs: [groupId],
        );
        final packages = await tx.query(
          'instagram_packages',
          where: 'id = ?',
          whereArgs: [packageId],
        );
        if (groups.isEmpty || packages.isEmpty) {
          throw StateError('Preparation claim or package unavailable.');
        }
        final group = _group(groups.single);
        final package = InstagramPackage.fromJson(
          jsonDecode(packages.single['payload'] as String)
              as Map<String, dynamic>,
        );
        if (package.operationId != 'attempt-group:$groupId:instagram' ||
            !samePackageSource(package, group.snapshot)) {
          throw ArgumentError('Package differs from the frozen review.');
        }
        await tx.update(
          'attempt_groups',
          {
            'instagram_state': 'ready',
            'instagram_package_id': packageId,
            'instagram_reason': null,
          },
          where: 'id = ?',
          whereArgs: [groupId],
        );
      });
  Future<void> failInstagram(String groupId) async {
    await database.db.update(
      'attempt_groups',
      {
        'instagram_state': 'failed',
        'instagram_reason': 'Preparation could not finish. Continue when ready; your draft and prepared versions are kept.',
      },
      where: "id = ? AND instagram_state = 'preparing'",
      whereArgs: [groupId],
    );
  }

  /// Startup recovery only changes local evidence. It never invokes a provider.
  Future<void> recoverInterrupted() => database.db.transaction((tx) async {
    final rows = await tx.query(
      'destination_attempts',
      where: "busy = 1 OR state IN ('preparing', 'sending')",
    );
    for (final row in rows) {
      final current = _attempt(row);
      final interruptedSend =
          current.outcome.status == PublishStatus.preparing ||
          current.outcome.status == PublishStatus.sending;
      final next = !interruptedSend
          ? current
          : current.copyWith(
              outcome: current.dispatchAt != null
                  ? _local(
                      PublishStatus.unknown,
                      'interrupted-after-dispatch',
                      'Publication may have completed. Check before deciding what to do next.',
                    )
                  : _local(
                      PublishStatus.pending,
                      'preparation-interrupted',
                      'Not sent — continue when ready',
                    ),
            );
      await _write(tx, next, 'recovered', busy: 0);
    }
    await tx.update('attempt_groups', {
      'instagram_state': 'pending',
      'instagram_reason': 'Preparation was interrupted. Continue when ready.',
    }, where: "instagram_state = 'preparing'");
  });

  Future<void> _write(
    DatabaseExecutor tx,
    DestinationAttempt next,
    String kind, {
    int? busy,
  }) async {
    await tx.update(
      'destination_attempts',
      {..._row(next), 'busy': ?busy},
      where: 'id = ?',
      whereArgs: [next.id],
    );
    await _event(tx, next, kind);
  }

  Future<void> _event(
    DatabaseExecutor tx,
    DestinationAttempt attempt,
    String kind,
  ) => tx
      .insert('attempt_events', {
        'attempt_id': attempt.id,
        'at': clock.now().toUtc().toIso8601String(),
        'payload': jsonEncode({'kind': kind, 'attempt': attempt.toJson()}),
      })
      .then((_) {});
  Map<String, Object?> _row(DestinationAttempt attempt) => {
    'id': attempt.id,
    'group_id': attempt.groupId,
    'parent_id': attempt.parentId,
    'destination': attempt.snapshot.destination.name,
    'state': attempt.outcome.status.name,
    'dispatch_at': attempt.dispatchAt?.toUtc().toIso8601String(),
    'payload': jsonEncode(attempt.toJson()),
  };
  AttemptGroup _group(Map<String, Object?> row) {
    final group = AttemptGroup.fromJson(
      jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    );
    if (group.id != row['id'] ||
        group.operationId != row['operation_id'] ||
        group.snapshot.draftId != row['draft_id'] ||
        group.snapshot.revision != row['revision']) {
      throw const FormatException('Group projection disagrees.');
    }
    return group;
  }

  DestinationAttempt _attempt(Map<String, Object?> row) {
    final attempt = DestinationAttempt.fromJson(
      jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    );
    if (attempt.id != row['id'] ||
        attempt.groupId != row['group_id'] ||
        attempt.parentId != row['parent_id'] ||
        attempt.snapshot.destination.name != row['destination'] ||
        attempt.outcome.status.name != row['state'] ||
        attempt.dispatchAt?.toUtc().toIso8601String() != row['dispatch_at'] ||
        attempt.snapshot.destination == Destination.instagram) {
      throw const FormatException('Attempt projection disagrees.');
    }
    return attempt;
  }

  Future<bool> _destinationCompleted(
    DatabaseExecutor tx,
    DestinationAttempt attempt,
  ) async => (await tx.query(
    'destination_attempts',
    columns: ['id'],
    where: "group_id = ? AND destination = ? AND state IN ('published', 'userReported')",
    whereArgs: [attempt.groupId, attempt.snapshot.destination.name],
    limit: 1,
  )).isNotEmpty;

  Future<void> _requireSavedRevision(
    DatabaseExecutor tx,
    ReviewedPost reviewed,
  ) async {
    final rows = await tx.query(
      'drafts',
      columns: ['revision', 'deleted_at'],
      where: 'id = ?',
      whereArgs: [reviewed.draftId],
    );
    if (rows.isEmpty ||
        rows.single['revision'] != reviewed.revision ||
        rows.single['deleted_at'] != null) {
      throw StateError(
        'The reviewed draft revision changed before this attempt was recorded.',
      );
    }
  }

  ReviewedPost _scope(ReviewedPost review, Destination destination) =>
      review.copyWith(
        posts: {destination: review.posts[destination]!},
        capabilityVersions: {
          destination: review.capabilityVersions[destination]!,
        },
      );

  void _validateReceipt(DestinationAttempt attempt, PublishOutcome outcome) {
    if (outcome.source != EvidenceSource.provider ||
        attempt.dispatchAt == null) {
      throw ArgumentError(
        'Publication requires durable dispatch and a provider receipt.',
      );
    }
    final id = outcome.remoteId!;
    Uri? expected;
    if (attempt.snapshot.destination == Destination.x) {
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(id)) {
        throw ArgumentError('Invalid X publication identifier.');
      }
      expected = Uri.parse('https://x.com/i/status/$id');
    } else {
      try {
        final uri = AtUri.parseStrict(id);
        if (uri.hostname != attempt.snapshot.account?.subject ||
            uri.collection.toString() != 'app.bsky.feed.post' ||
            !isValidTid(uri.rkey)) {
          throw const FormatException();
        }
        expected = Uri.https(
          'bsky.app',
          '/profile/${uri.hostname}/post/${uri.rkey}',
        );
      } catch (_) {
        throw ArgumentError('Invalid Bluesky publication receipt.');
      }
    }
    if (outcome.url != null && outcome.url != expected) {
      throw ArgumentError(
        'Publication link disagrees with its official identifier.',
      );
    }
  }
}
