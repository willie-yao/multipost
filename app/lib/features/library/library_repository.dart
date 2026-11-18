import '../drafts/draft.dart';
import '../drafts/draft_repository.dart';
import '../instagram/instagram_package.dart';
import '../instagram/instagram_repository.dart';
import '../publishing/attempt.dart';
import '../publishing/attempt_repository.dart';

class LibraryAttention {
  LibraryAttention({
    this.group,
    this.package,
    required List<Destination> destinations,
    List<DestinationAttempt> outcomes = const [],
    this.preparation,
    this.hasInstagramPackage = false,
    this.instagramState,
  }) : destinations = List.unmodifiable(destinations),
       outcomes = List.unmodifiable(outcomes);
  final AttemptGroup? group;
  final InstagramPackage? package;
  final List<Destination> destinations;

  /// Read-only copies of what Results shows, so the row can carry one
  /// state mark per destination.
  final List<DestinationAttempt> outcomes;
  final InstagramPreparation? preparation;
  final bool hasInstagramPackage;
  final InstagramState? instagramState;
}

class LibraryRepository {
  LibraryRepository(this.drafts, this.instagram, {this.attempts});
  final InstagramRepository instagram;
  final DraftRepository drafts;
  final AttemptRepository? attempts;

  Future<List<Draft>> listDrafts() async {
    final result = <Draft>[];
    for (final draft in await drafts.list()) {
      if (attempts == null) {
        result.add(draft);
        continue;
      }
      if (draft.retryParentAttemptId case final parent?) {
        if (await attempts!.childForOperation(
              parent,
              draft.retryOperationId!,
            ) ==
            null) {
          result.add(draft);
        }
      } else if (await attempts!.getGroupForDraft(draft.id) == null) {
        result.add(draft);
      }
    }
    return result;
  }

  Future<List<AttemptGroup>> listGroups() async =>
      await attempts?.listGroups() ?? [];

  Future<List<InstagramPackage>> _standalone(
    List<InstagramPackage> packages,
  ) async {
    final operations = {
      for (final group in await listGroups())
        'attempt-group:${group.id}:instagram',
    };
    return packages
        .where((package) => !operations.contains(package.operationId))
        .toList();
  }

  Future<List<InstagramPackage>> markedInstagram() async =>
      _standalone(await instagram.marked());
  Future<List<InstagramPackage>> pendingInstagram() async =>
      _standalone(await instagram.pending());

  Future<List<LibraryAttention>> listAttention() async {
    final result = <LibraryAttention>[];
    for (final group in await listGroups()) {
      final outcomes = await attempts!.effectiveAttempts(group.id);
      var pending = outcomes.any(
        (a) => !{
          PublishStatus.published,
          PublishStatus.userReported,
        }.contains(a.outcome.status),
      );
      final preparation = await attempts!.instagramPreparation(group.id);
      InstagramPackage? package;
      InstagramState? instagramState;
      if (preparation != null) {
        package = preparation.packageId == null
            ? null
            : await instagram.get(preparation.packageId!);
        if (package != null) {
          instagramState = (await instagram.progress(package.id)).state;
        }
        pending =
            pending ||
            package == null ||
            instagramState != InstagramState.userMarked;
      }
      if (pending) {
        result.add(
          LibraryAttention(
            group: group,
            destinations: Destination.values
                .where(group.snapshot.posts.containsKey)
                .toList(),
            outcomes: outcomes,
            preparation: preparation,
            hasInstagramPackage: package != null,
            instagramState: instagramState,
          ),
        );
      }
    }
    for (final package in await pendingInstagram()) {
      result.add(
        LibraryAttention(
          package: package,
          destinations: [Destination.instagram],
        ),
      );
    }
    return result;
  }
}
