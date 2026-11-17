import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';

/// Save a user-requested compose advance. If that stage never reaches storage,
/// restore only this attempt's stage while retaining the latest content edits.
Future<bool> saveComposeStage(
  DraftController controller,
  ComposeStage stage,
) async {
  if (!await controller.flush()) return false;
  final previous = controller.draft.stage;
  controller.change(setStage(controller.draft, stage, DateTime.now().toUtc()));
  final advancedRevision = controller.draft.revision;
  var ownsStage = true;
  void observe() {
    if (controller.draft.stage != stage) ownsStage = false;
  }

  controller.addListener(observe);
  try {
    if (await controller.flush()) return true;
    if (ownsStage &&
        controller.draft.stage == stage &&
        controller.savedRevision < advancedRevision) {
      controller.change(
        setStage(controller.draft, previous, DateTime.now().toUtc()),
      );
      await controller.flush();
    }
    return false;
  } finally {
    controller.removeListener(observe);
  }
}
