import 'package:image_picker/image_picker.dart';

import '../../storage/media_files.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'picker_imports.dart';

/// The foreground draft-media operation. Callers hold their local busy guard
/// throughout this future, including the native picker and final acknowledgment.
/// Errors deliberately retain the journal for explicit library recovery.
Future<bool> pickDraftMedia({
  required DraftController controller,
  required MediaFiles media,
  required PickerImports pickerImports,
  required bool canLaunchPicker,
  Destination? destination,
  String? replacementAssetId,
  ImagePicker? picker,
}) async {
  if (!canLaunchPicker) {
    throw const MediaFileException(
      'Media recovery is not ready. Return to your posts to resolve the previous selection.',
    );
  }
  if (!await controller.flush()) return false;
  final original = controller.draft;
  if (original.deletedAt != null) {
    throw StateError('The original draft is unavailable.');
  }
  final operation = await pickerImports.begin(
    draftId: original.id,
    draftRevision: original.revision,
    destination: destination,
    replacementAssetId: replacementAssetId,
  );
  final nativePicker = picker ?? ImagePicker();
  final photosOnly = destination == Destination.instagram;
  late final List<XFile> selection;
  if (replacementAssetId != null) {
    final file = photosOnly
        ? await nativePicker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          )
        : await nativePicker.pickMedia(requestFullMetadata: false);
    selection = [?file];
  } else {
    selection = photosOnly
        ? await nativePicker.pickMultiImage(requestFullMetadata: false)
        : await nativePicker.pickMultipleMedia(requestFullMetadata: false);
  }
  final ready = await pickerImports.complete(operation.id, selection);
  if (ready.cancelled) return true;
  if (!identical(controller.draft, original)) {
    throw StateError(
      'The original draft changed. Your selection is kept for recovery in Your posts.',
    );
  }
  for (final asset in ready.assets) {
    await media.fileFor(asset.id);
    if (photosOnly && !asset.mimeType.startsWith('image/')) {
      throw const MediaFileException(
        'Instagram uses feed photos only. Your selection is kept; return to Your posts to resolve it.',
      );
    }
  }
  // Recheck after file IO; a controller edit must never redirect a late result.
  if (!identical(controller.draft, original)) {
    throw StateError(
      'The original draft changed. Your selection is kept for recovery in Your posts.',
    );
  }
  final previous = destination == null
      ? original.shared.media
      : resolveContent(original, destination).media;
  final next = [...previous];
  final imported = ready.assets.map((a) => Attachment(assetId: a.id)).toList();
  if (replacementAssetId == null) {
    next.addAll(imported);
  } else {
    final index = next.indexWhere((a) => a.assetId == replacementAssetId);
    if (index < 0) {
      throw StateError(
        'The original attachment changed. Resolve this selection in Your posts.',
      );
    }
    next.replaceRange(index, index + 1, imported);
  }
  controller.change(
    destination == null
        ? editSharedMedia(original, next, DateTime.now().toUtc())
        : editOwnMedia(original, destination, next, DateTime.now().toUtc()),
  );
  if (!await controller.flush()) return false;
  await pickerImports.acknowledge(ready.id);
  return true;
}
