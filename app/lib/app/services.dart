import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../features/accounts/account_repository.dart';
import '../features/drafts/draft.dart';
import '../features/drafts/draft_editor.dart';
import '../features/drafts/draft_repository.dart';
import '../features/instagram/instagram_repository.dart';
import '../features/instagram/instagram_service.dart';
import '../features/media/picker_imports.dart';
import '../features/review/review_service.dart';
import '../storage/local_database.dart';
import '../storage/media_files.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.media,
    required this.drafts,
    required this.accounts,
    required this.clock,
    required this.ids,
    required this.instagramPackageRoot,
    this.onClose,
  }) : pickerImports = PickerImports(media, ids);
  final LocalDatabase database;
  final MediaFiles media;
  final DraftRepository drafts;
  final AccountRepository accounts;
  final Clock clock;
  final Ids ids;
  final PickerImports pickerImports;
  final Directory instagramPackageRoot;
  late final instagramPolicy = InstagramPhotoPolicy.localPreparation();
  late final instagramRepo = InstagramRepository(database);
  late final review = ReviewService(
    drafts,
    media,
    accounts,
    InstagramPreparationValidators(instagramPolicy),
    clock,
  );
  late final instagram = InstagramService(
    instagramRepo,
    media,
    instagramPackageRoot,
    instagramPolicy,
    ids,
    clock,
  );
  final Future<void> Function()? onClose;
  bool pickerRecoveryReady = false;
  Object? pickerRecoveryError;
  PickerImportOperation? recoveredPicker;
  Future<void>? _recovery;

  static Future<AppServices> open() async {
    final support = await getApplicationSupportDirectory();
    final database = await LocalDatabase.open(
      databaseFactory,
      p.join(support.path, 'caption.db'),
    );
    final media = MediaFiles(
      database,
      Directory(p.join(support.path, 'media')),
      const Ids(),
    );
    return AppServices(
      // path_provider_android 2.3.1 getApplicationSupportPath returns filesDir.
      // I3 FileProvider must scope files-path to exactly instagram-packages/.
      instagramPackageRoot: Directory(
        p.join(support.path, 'instagram-packages'),
      ),
      database: database,
      media: media,
      drafts: SqliteDraftRepository(database, media: media),
      accounts: LocalAccountRepository(database),
      clock: const Clock(),
      ids: const Ids(),
    );
  }

  /// Bootstrap must await this; callers check pickerRecoveryReady before begin.
  /// A failed recovery keeps the journal and blocks launches for explicit repair.
  Future<void> recoverPicker(ImagePicker picker) =>
      _recovery ??= _recoverPicker(picker).whenComplete(() => _recovery = null);
  Future<void> _recoverPicker(ImagePicker picker) async {
    pickerRecoveryReady = false;
    pickerRecoveryError = null;
    try {
      recoveredPicker = await pickerImports.recoverLost(picker);
      pickerRecoveryReady = true;
    } catch (error) {
      pickerRecoveryError = error;
      try {
        recoveredPicker = await pickerImports.unresolved();
      } catch (_) {
        /* Keep the original error visible. */
      }
    }
  }

  Future<void> refreshPicker() async {
    recoveredPicker = await pickerImports.unresolved();
  }

  /// Explicit recovery applies only to the journal's saved draft and target.
  /// Unique operation asset IDs recognize save-before-ack restart without duplicates.
  Future<void> attachRecovered(PickerImportOperation requested) async {
    final operation = await pickerImports.unresolved();
    if (operation == null || operation.id != requested.id) {
      throw StateError(
        'This selection has already been resolved. Keep the current draft.',
      );
    }
    if (!operation.isComplete) {
      throw StateError(
        'This selection is incomplete. Discard it and choose again.',
      );
    }
    final draft = await drafts.get(operation.draftId);
    if (draft == null || draft.deletedAt != null) {
      throw StateError(
        'The original draft is unavailable. Keep or discard this selection.',
      );
    }
    final current = resolveContent(
      draft,
      operation.destination ?? Destination.x,
    ).media;
    final target = operation.destination == null ? draft.shared.media : current;
    final imported = operation.assets
        .map((a) => Attachment(assetId: a.id))
        .toList();
    final alreadyAttached =
        draft.revision == operation.draftRevision + 1 &&
        imported.isNotEmpty &&
        target.length >= imported.length &&
        List.generate(target.length - imported.length + 1, (i) => i).any(
          (i) => List.generate(
            imported.length,
            (j) => target[i + j].assetId == imported[j].assetId,
          ).every((v) => v),
        ) &&
        (operation.replacementAssetId == null ||
            !target.any((a) => a.assetId == operation.replacementAssetId));
    if (!alreadyAttached) {
      if (draft.revision != operation.draftRevision) {
        throw StateError(
          'The original draft changed. This selection was kept; discard it and choose again from that draft.',
        );
      }
      final nextMedia = [...target];
      if (operation.replacementAssetId case final replacement?) {
        final index = nextMedia.indexWhere((a) => a.assetId == replacement);
        if (index < 0) {
          throw StateError(
            'The original attachment changed. Keep or discard this selection.',
          );
        }
        nextMedia.replaceRange(index, index + 1, imported);
      } else {
        nextMedia.addAll(imported);
      }
      final next = operation.destination == null
          ? editSharedMedia(draft, nextMedia, clock.now())
          : editOwnMedia(draft, operation.destination!, nextMedia, clock.now());
      await drafts.save(next, expectedRevision: draft.revision);
    }
    await pickerImports.acknowledge(operation.id);
    await refreshPicker();
    pickerRecoveryError = null;
    pickerRecoveryReady = true;
  }

  Future<void> discardRecovered(PickerImportOperation requested) async {
    final operation = await pickerImports.unresolved();
    if (operation == null || operation.id != requested.id) {
      throw StateError('This selection has already been resolved.');
    }
    if (operation.isComplete) {
      await pickerImports.acknowledge(operation.id);
    } else {
      await pickerImports.cancel(operation.id);
    }
    await refreshPicker();
    pickerRecoveryError = null;
    pickerRecoveryReady = true;
  }

  Future<void> close() async {
    await database.close();
    await onClose?.call();
  }
}
