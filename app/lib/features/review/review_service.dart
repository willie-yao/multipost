import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../accounts/account_repository.dart';
import '../drafts/draft.dart';
import '../drafts/draft_editor.dart';
import '../drafts/draft_repository.dart';
import 'review.dart';

abstract interface class DestinationValidator {
  String get version;
  FutureOr<List<ReviewIssue>> validate(ResolvedPost post);
}

abstract interface class ValidatorRegistry {
  DestinationValidator forDestination(Destination destination);
}

/// Conservative fallback; local Instagram preparation uses its explicit policy.
class LocalValidators implements ValidatorRegistry {
  const LocalValidators();
  @override
  DestinationValidator forDestination(Destination destination) =>
      const _LocalValidator();
}

class _LocalValidator implements DestinationValidator {
  const _LocalValidator();
  @override
  String get version => 'local-unverified-1';
  @override
  List<ReviewIssue> validate(ResolvedPost post) => [
    _issue(
      post.destination,
      'requirements-unverified',
      "Couldn't check current requirements",
    ),
    if (post.destination == Destination.instagram && post.content.media.isEmpty)
      _issue(
        post.destination,
        'instagram-photos-required',
        'Choose photos for Instagram.',
      ),
    if (post.destination == Destination.instagram &&
        post.assets.any((asset) => !asset.mimeType.startsWith('image/')))
      _issue(
        post.destination,
        'instagram-photos-only',
        'Instagram preparation supports photos only. Choose own photos or leave Instagram out; shared video stays in your draft.',
      ),
    if (post.content.text.trim().isEmpty && post.content.media.isNotEmpty)
      _issue(
        post.destination,
        'media-only-unverified',
        'Media-only posting requirements have not been verified.',
      ),
  ];
}

class StaleReviewException implements Exception {
  const StaleReviewException();
  @override
  String toString() => 'This post changed. Review it again.';
}

class ReviewService {
  ReviewService(
    this._drafts,
    this.media,
    this._accounts,
    this._validators,
    this._clock,
  );
  final DraftRepository _drafts;
  final MediaFiles media;
  final AccountRepository _accounts;
  final ValidatorRegistry _validators;
  final Clock _clock;

  Future<void> _requirePersisted(Draft draft) async {
    final stored = await _drafts.get(draft.id);
    if (stored == null || stored.deletedAt != null || stored != draft) {
      throw const StaleReviewException();
    }
  }

  Future<ReviewResult> review(Draft draft, {bool? directOnline}) =>
      _review(draft, directOnline: directOnline);

  Future<ReviewResult> _review(
    Draft draft, {
    bool? directOnline,
    bool requirePersisted = true,
  }) async {
    if (requirePersisted) await _requirePersisted(draft);
    List<AccountView>? accounts;
    var assisted = true;
    var assistedChecked = true;
    try {
      accounts = await _accounts.list();
    } catch (_) {
      // A missing check becomes an issue for every affected selected destination.
    }
    if (draft.selected.contains(Destination.instagram)) {
      try {
        assisted = await _accounts.instagramAssistedSharing();
      } catch (_) {
        assistedChecked = false;
      }
    }
    final posts = <Destination, ResolvedPost>{};
    final versions = <Destination, String>{};
    final issues = <ReviewIssue>[];
    for (final destination in Destination.values.where(
      draft.selected.contains,
    )) {
      final content = resolveContent(draft, destination);
      final assets = <MediaAsset>[];
      for (final attachment in content.media) {
        try {
          final asset = await media.find(attachment.assetId);
          if (asset == null) {
            throw const MediaFileException('Media is missing.');
          }
          final file = await media.fileFor(asset.id);
          final hash = (await sha256.bind(file.openRead()).first).toString();
          if (hash != asset.sha256 || await media.find(asset.id) != asset) {
            throw const MediaFileException('Media changed or is damaged.');
          }
          assets.add(asset);
        } catch (_) {
          issues.add(
            _issue(
              destination,
              'media-unavailable',
              'A media item is missing or damaged. Edit this version to replace or remove it.',
            ),
          );
        }
      }
      AccountIdentity? identity;
      if (destination != Destination.instagram) {
        final matching = accounts
            ?.where((account) => account.destination == destination)
            .toList();
        final account = matching?.length == 1 ? matching!.single : null;
        identity = account?.identity;
        if (account?.state == AccountState.unavailable) {
          issues.add(
            _issue(
              destination,
              'not-available',
              "Posting to ${destinationName(destination)} isn't available in this build. Leave it out to publish the others.",
            ),
          );
        } else if (accounts == null || (matching?.length ?? 0) > 1) {
          issues.add(
            _issue(
              destination,
              'validation-unavailable',
              "Couldn't check current requirements",
            ),
          );
        } else if (account?.state == AccountState.expired) {
          issues.add(
            _issue(
              destination,
              'connection-expired',
              'Connection expired. Reconnect ${destinationName(destination)} to publish this version.',
            ),
          );
        } else if (account?.state != AccountState.connected ||
            identity == null ||
            identity.destination != destination ||
            identity.subject.isEmpty ||
            identity.handle.isEmpty) {
          issues.add(
            _issue(
              destination,
              'connection-needed',
              'Connect ${destinationName(destination)} before publishing this version.',
            ),
          );
        }
        if (directOnline != true) {
          issues.add(
            _issue(
              destination,
              directOnline == false ? 'offline' : 'connectivity-unverified',
              directOnline == false
                  ? 'You are offline. Connect before publishing this version.'
                  : 'Connection availability has not been checked.',
            ),
          );
        }
      } else if (!assistedChecked) {
        issues.add(
          _issue(
            destination,
            'validation-unavailable',
            "Couldn't check current requirements",
          ),
        );
      } else if (!assisted) {
        issues.add(
          _issue(
            destination,
            'assisted-sharing-off',
            'Instagram assisted sharing is off. Enable it in Accounts or leave Instagram out.',
          ),
        );
      }
      final post = ResolvedPost(
        destination: destination,
        content: content,
        ownCaption: draft.versions[destination]?.ownText != null,
        assets: assets,
        account: identity,
      );
      posts[destination] = post;
      issues.addAll(sharedContentIssues(post));
      try {
        final validator = _validators.forDestination(destination);
        final version = validator.version;
        if (version.isEmpty) throw StateError('Missing capability version');
        versions[destination] = version;
        final checked = await validator.validate(post);
        if (checked.any((issue) => issue.destination != destination)) {
          throw StateError('Mismatched validation destination');
        }
        issues.addAll(checked);
      } catch (_) {
        versions[destination] = 'unavailable';
        issues.add(
          _issue(
            destination,
            'validation-unavailable',
            "Couldn't check current requirements",
          ),
        );
      }
    }
    if (requirePersisted) await _requirePersisted(draft);
    return ReviewResult(
      snapshot: ReviewedPost(
        draftId: draft.id,
        revision: draft.revision,
        posts: posts,
        capabilityVersions: versions,
        reviewedAt: _clock.now(),
      ),
      issues: issues,
    );
  }

  /// Fresh validation for a new submission/child, scoped to only its destinations.
  Future<ReviewResult> revalidateSaved(
    ReviewedPost snapshot, {
    required Set<Destination> destinations,
    bool? directOnline,
  }) async {
    final draft = await _drafts.get(snapshot.draftId);
    if (draft == null ||
        draft.deletedAt != null ||
        draft.revision != snapshot.revision) {
      throw const StaleReviewException();
    }
    final current = await review(draft, directOnline: directOnline);
    return _requireSame(snapshot, current, destinations);
  }

  /// Rechecks the exact retained content, never a newer editable draft version.
  /// A synthetic source is only an input to the same owned-file/account/policy
  /// validation; it is never saved or substituted for the frozen snapshot.
  Future<ReviewResult> revalidateFrozen(
    ReviewedPost snapshot, {
    required Set<Destination> destinations,
    bool? directOnline,
  }) async {
    _requireDestinations(snapshot, destinations);
    final posts = destinations.map((d) => snapshot.posts[d]!).toList();
    final sharedText =
        posts
            .where((p) => !p.ownCaption)
            .map((p) => p.content.text)
            .firstOrNull ??
        '';
    if (posts.any((p) => !p.ownCaption && p.content.text != sharedText)) {
      throw const StaleReviewException();
    }
    final source = Draft(
      id: snapshot.draftId,
      revision: snapshot.revision,
      updatedAt: snapshot.reviewedAt,
      selected: destinations,
      shared: PostContent(text: sharedText),
      versions: {
        for (final post in posts)
          post.destination: DestinationVersion(
            ownText: post.ownCaption ? post.content.text : null,
            ownMedia: post.content.media,
          ),
      },
    );
    final current = await _review(
      source,
      directOnline: directOnline,
      requirePersisted: false,
    );
    return _requireSame(snapshot, current, destinations);
  }

  void _requireDestinations(
    ReviewedPost snapshot,
    Set<Destination> destinations,
  ) {
    if (destinations.isEmpty ||
        !snapshot.posts.keys.toSet().containsAll(destinations)) {
      throw const StaleReviewException();
    }
  }

  ReviewResult _requireSame(
    ReviewedPost snapshot,
    ReviewResult current,
    Set<Destination> destinations,
  ) {
    _requireDestinations(snapshot, destinations);
    for (final destination in destinations) {
      if (snapshot.posts[destination] != current.snapshot.posts[destination] ||
          snapshot.capabilityVersions[destination] !=
              current.snapshot.capabilityVersions[destination]) {
        throw const StaleReviewException();
      }
    }
    return ReviewResult(
      snapshot: snapshot.copyWith(
        posts: {for (final d in destinations) d: snapshot.posts[d]!},
        capabilityVersions: {
          for (final d in destinations) d: snapshot.capabilityVersions[d]!,
        },
      ),
      issues: current.issues
          .where((i) => destinations.contains(i.destination))
          .toList(),
    );
  }

  /// Caller must flush its controller first and reject local edits after awaits.
  /// Check result.canProceed and local revision/readiness again before delegation.
  /// This produces fresh evidence only; it never sends or prepares a post.
  Future<ReviewResult> revalidate(
    ReviewedPost snapshot,
    Draft draft, {
    bool? directOnline,
  }) async {
    if (snapshot.draftId != draft.id || snapshot.revision != draft.revision) {
      throw const StaleReviewException();
    }
    final current = await review(draft, directOnline: directOnline);
    if (!mapEquals(snapshot.posts, current.snapshot.posts) ||
        !mapEquals(
          snapshot.capabilityVersions,
          current.snapshot.capabilityVersions,
        )) {
      throw const StaleReviewException();
    }
    return current;
  }
}

ReviewIssue _issue(Destination destination, String code, String message) =>
    ReviewIssue(
      destination: destination,
      code: code,
      message: message,
      blocking: true,
    );

String reviewActionLabel(Set<Destination> destinations) {
  final direct = destinations.where((d) => d != Destination.instagram).toList();
  if (destinations.contains(Destination.instagram)) {
    return direct.isEmpty ? 'Prepare Instagram' : 'Publish & prepare';
  }
  return direct.length == 1
      ? 'Publish to ${destinationName(direct.single)}'
      : 'Publish to ${direct.length} accounts';
}

/// Single owner for app-wide content rules, also used by provider.send.
List<ReviewIssue> sharedContentIssues(ResolvedPost post) {
  final issues = <ReviewIssue>[];
  void issue(String code, String message) =>
      issues.add(_issue(post.destination, code, message));
  if (post.content.text.trim().isEmpty && post.content.media.isEmpty) {
    issue('empty-post', 'Add a caption or media to this version.');
  }
  final videos = post.assets
      .where((a) => a.mimeType.startsWith('video/'))
      .length;
  final photos = post.assets
      .where((a) => a.mimeType.startsWith('image/'))
      .length;
  if (videos > 0 && photos > 0) {
    issue('mixed-media', 'Use photos or one video in this version.');
  }
  if (videos > 1) {
    issue('multiple-videos', 'Use only one video in this version.');
  }
  if (videos + photos != post.assets.length) {
    issue(
      'unsupported-media',
      'This media type is unsupported. Replace or remove it.',
    );
  }
  return issues;
}
