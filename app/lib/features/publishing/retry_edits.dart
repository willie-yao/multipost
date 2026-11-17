import '../../core/clock.dart';
import '../drafts/draft.dart';
import '../drafts/draft_repository.dart';
import 'attempt.dart';
import 'attempt_repository.dart';

/// The relationship is saved atomically with the scoped draft itself. No risk
/// acceptance is stored: Unknown always needs a new explicit human decision.
class RetryEdits {
  RetryEdits(this.drafts, this.attempts, this.clock);
  final DraftRepository drafts;
  final AttemptRepository attempts;
  final Clock clock;

  Future<Draft> open(String parentId) async {
    final parent = await attempts.getAttempt(parentId);
    if (parent == null ||
        !(ordinaryRetryAllowed(parent.outcome) ||
            parent.outcome.status == PublishStatus.unknown)) {
      throw StateError('This version cannot be reviewed for another attempt.');
    }
    final effective = await attempts.effectiveAttempts(parent.groupId);
    if (!effective.any((a) => a.id == parentId)) {
      throw StateError('Open the current result before deciding what to do.');
    }
    final id = 'retry:$parentId';
    var existing = await drafts.get(id);
    if (existing == null) {
      final post = parent.snapshot;
      final draft = Draft(
        id: id,
        updatedAt: clock.now(),
        stage: ComposeStage.review,
        selected: {post.destination},
        shared: post.content,
        versions: post.ownCaption
            ? {post.destination: DestinationVersion(ownText: post.content.text)}
            : {},
        retryParentAttemptId: parent.id,
        retryOperationId: 'retry:$parentId',
      );
      try {
        await drafts.save(draft, expectedRevision: -1);
        return draft;
      } on DraftConflict {
        existing = await drafts.get(id);
      }
    }
    if (existing == null ||
        existing.retryParentAttemptId != parentId ||
        existing.retryOperationId != 'retry:$parentId') {
      throw StateError(
        'This recovery draft needs local repair. Its content is kept.',
      );
    }
    if (existing.deletedAt != null) {
      await drafts.setDeleted(id, null);
      existing = (await drafts.get(id))!;
    }
    return existing;
  }
}
