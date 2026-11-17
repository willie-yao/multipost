import 'dart:async';

import '../../core/clock.dart';
import '../drafts/draft.dart';
import '../instagram/instagram_service.dart';
import '../providers/provider.dart';
import '../review/review.dart';
import '../review/review_service.dart';
import 'attempt.dart';
import 'attempt_repository.dart';

class PublishReviewRejected implements Exception {
  PublishReviewRejected(this.result);
  final ReviewResult result;
  @override
  String toString() =>
      result.issues.where((i) => i.blocking).map((i) => i.message).join(' ');
}

/// Human actions only. Construction, recovery and Check never start a send.
class PublishCoordinator {
  PublishCoordinator({
    required this.attempts,
    required this.review,
    required this.instagram,
    required Map<Destination, PublishProvider> providers,
    this.clock = const Clock(),
    this.directOnline,
  }) : providers = Map.unmodifiable(providers) {
    if (providers.entries.any(
      (e) => e.key == Destination.instagram || e.key != e.value.destination,
    )) {
      throw ArgumentError('Direct provider destinations disagree.');
    }
  }
  final AttemptRepository attempts;
  final ReviewService review;
  final InstagramService instagram;
  final Map<Destination, PublishProvider> providers;
  final Clock clock;

  /// Point-in-time availability only; it cannot grant capabilities/authorization.
  /// null/error is unverified. There is no connectivity listener or send trigger.
  final FutureOr<bool?> Function()? directOnline;

  Future<bool?> _online() async {
    try {
      return await directOnline?.call();
    } catch (_) {
      return null;
    }
  }

  void _requireReady(ReviewResult result) {
    if (!result.canProceed) throw PublishReviewRejected(result);
  }

  Future<String> confirm(
    ReviewedPost reviewed, {
    required String operationId,
  }) async {
    final existing = await attempts.findExisting(reviewed, operationId);
    if (existing != null) return existing.id;
    _requireReady(
      await review.revalidateSaved(
        reviewed,
        destinations: reviewed.posts.keys.toSet(),
        directOnline: await _online(),
      ),
    );
    final begun = await attempts.begin(reviewed, operationId);
    if (!begun.created) return begun.group.id;
    if (reviewed.posts.containsKey(Destination.instagram)) {
      await _prepareInstagram(begun.group);
    }
    for (final attempt in await attempts.attempts(begun.group.id)) {
      await _send(attempt.id);
    }
    return begun.group.id;
  }

  Future<String> retry(
    String attemptId,
    ReviewedPost reviewed, {
    required String operationId,
  }) => _retry(attemptId, reviewed, operationId);
  Future<String> _retry(
    String attemptId,
    ReviewedPost reviewed,
    String operationId, {
    bool allowUnknown = false,
  }) async {
    final existing = await attempts.childForOperation(attemptId, operationId);
    if (existing != null) return existing;
    final parent = await _attempt(attemptId);
    if (!(ordinaryRetryAllowed(parent.outcome) ||
        allowUnknown && parent.outcome.status == PublishStatus.unknown)) {
      throw StateError('This outcome cannot be retried.');
    }
    _requireReady(
      await review.revalidateSaved(
        reviewed,
        destinations: {parent.snapshot.destination},
        directOnline: await _online(),
      ),
    );
    final child = await attempts.createChild(
      attemptId,
      reviewed,
      operationId,
      allowUnknown: allowUnknown,
    );
    if (child.created) await _send(child.attempt.id);
    return child.attempt.id;
  }

  Future<void> check(String attemptId) async {
    if (!await attempts.claimCheck(attemptId)) return;
    final attempt = await _attempt(attemptId);
    try {
      final provider = providers[attempt.snapshot.destination];
      if (provider == null) {
        await attempts.record(attemptId, attempt.outcome);
        return;
      }
      final outcome = await provider.check(
        attempt.snapshot,
        attempt.outcome,
        _context(attempt, mayDispatch: false),
      );
      await attempts.record(attemptId, outcome);
    } catch (_) {
      // A failed read cannot establish nonpublication or start a create.
      try {
        await attempts.record(attemptId, attempt.outcome);
      } catch (_) {
        /* Recovery retains the last evidence if storage is unavailable. */
      }
    }
  }

  Future<void> reportFound(String attemptId) => attempts.reportFound(attemptId);

  Future<String> resendAfterCheck(
    String attemptId,
    ReviewedPost reviewed, {
    required String operationId,
    required bool duplicateRiskAccepted,
  }) async {
    if (!duplicateRiskAccepted) {
      throw StateError('An explicit duplicate-risk decision is required.');
    }
    final existing = await attempts.childForOperation(attemptId, operationId);
    if (existing != null) return existing;
    final before = await _attempt(attemptId);
    if (before.outcome.status != PublishStatus.unknown) {
      throw StateError('Only unknown publication uses this action.');
    }
    await check(attemptId);
    return _retry(attemptId, reviewed, operationId, allowUnknown: true);
  }

  Future<void> continuePending(
    String groupId,
    ReviewedPost reviewed, {
    required Set<String> attemptIds,
  }) async {
    if (attemptIds.isEmpty) {
      throw ArgumentError('Select an unsent attempt to continue.');
    }
    final selected = <DestinationAttempt>[];
    for (final id in attemptIds) {
      final attempt = await _attempt(id);
      if (attempt.groupId != groupId) {
        throw StateError('Attempt belongs to another group.');
      }
      final frozen = await attempts.reviewForAttempt(id);
      _requireFrozenMatch(frozen, reviewed, attempt.snapshot.destination);
      if (attempt.dispatchAt != null ||
          !(attempt.outcome.status == PublishStatus.pending ||
              attempt.outcome.status == PublishStatus.processing &&
                  attempt.outcome.reasonCode == 'preparation-ready')) {
        throw StateError(
          'Only unsent pending or ready preparation can continue.',
        );
      }
      selected.add(attempt);
    }
    // Validate every selected frozen source before claiming any of this action.
    for (final attempt in selected) {
      final frozen = await attempts.reviewForAttempt(attempt.id);
      _requireReady(
        await review.revalidateFrozen(
          frozen,
          destinations: {attempt.snapshot.destination},
          directOnline: await _online(),
        ),
      );
    }
    for (final attempt in selected) {
      await _send(attempt.id);
    }
  }

  Future<void> continueInstagram(String groupId, ReviewedPost reviewed) async {
    final group = await attempts.getGroup(groupId);
    if (group == null ||
        !group.snapshot.posts.containsKey(Destination.instagram)) {
      throw StateError('Instagram preparation unavailable.');
    }
    _requireFrozenMatch(group.snapshot, reviewed, Destination.instagram);
    final preparation = await attempts.instagramPreparation(groupId);
    if (preparation?.state == InstagramPreparationState.ready) return;
    _requireReady(
      await review.revalidateFrozen(
        group.snapshot,
        destinations: {Destination.instagram},
        directOnline: await _online(),
      ),
    );
    await _prepareInstagram(group);
  }

  void _requireFrozenMatch(
    ReviewedPost frozen,
    ReviewedPost supplied,
    Destination destination,
  ) {
    if (frozen.draftId != supplied.draftId ||
        frozen.revision != supplied.revision ||
        frozen.posts[destination] != supplied.posts[destination] ||
        frozen.capabilityVersions[destination] !=
            supplied.capabilityVersions[destination]) {
      throw const StaleReviewException();
    }
  }

  Future<void> _prepareInstagram(AttemptGroup group) async {
    if (!await attempts.claimInstagram(group.id)) return;
    try {
      final preparation = (await attempts.instagramPreparation(group.id))!;
      // prepare owns source checking and findByOperation idempotency, including
      // a committed package whose group association was lost to process death.
      final package = await instagram.prepare(
        group.snapshot,
        operationId: preparation.operationId,
      );
      await attempts.completeInstagram(group.id, package.id);
    } catch (_) {
      try {
        await attempts.failInstagram(group.id);
      } catch (_) {
        /* Recovery retains the interrupted preparation. */
      }
    }
  }

  Future<void> _send(String id) async {
    var claimed = false;
    try {
      if (!await attempts.claim(id)) return;
      claimed = true;
      final attempt = await _attempt(id);
      final provider = providers[attempt.snapshot.destination];
      final outcome = provider == null
          ? PublishOutcome(
              status: PublishStatus.connectionNeeded,
              source: EvidenceSource.local,

              at: clock.now(),
              reasonCode: 'provider-unavailable',
              message: 'Publishing setup is unavailable. Keep this reviewed version.',
            )
          : await provider.send(
              attempt.snapshot,
              _context(attempt, mayDispatch: true),
            );
      await attempts.record(id, outcome);
    } catch (error) {
      if (!claimed) return;
      // Distinguish durable pre-create failure from a response lost after create.
      // If even this write fails, the retained preparing/sending row is recovered
      // conservatively on restart; another destination keeps its own boundary.
      try {
        final current = await _attempt(id);
        final dispatched = current.dispatchAt != null;
        await attempts.record(
          id,
          PublishOutcome(
            status: dispatched
                ? PublishStatus.unknown
                : PublishStatus.notPublished,
            source: EvidenceSource.local,
            remoteId: error is UnrecordedReceipt
                ? error.remoteId
                : current.outcome.remoteId,
            at: clock.now(),
            reasonCode: dispatched
                ? 'create-unconfirmed'
                : 'preparation-failed',
            message: dispatched
                ? 'Publication may have completed. Check before deciding what to do next.'
                : 'This version was not sent. Review before retrying.',
          ),
        );
      } catch (_) {
        /* Keep durable prior evidence for recovery. */
      }
    }
  }

  PublishContext _context(
    DestinationAttempt attempt, {
    required bool mayDispatch,
  }) => PublishContext(
    attemptId: attempt.id,
    uploadState: attempt.uploadState,
    markDispatch: mayDispatch
        ? () => attempts.markDispatch(attempt.id)
        : () async {
            throw StateError('Check cannot dispatch publication.');
          },
    saveUpload: (key, value) => attempts.saveUpload(attempt.id, key, value),
  );
  Future<DestinationAttempt> _attempt(String id) async {
    final attempt = await attempts.getAttempt(id);
    if (attempt == null) throw StateError('Attempt unavailable.');
    return attempt;
  }
}
