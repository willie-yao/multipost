import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/media/draft_media_picker.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

class SelectionPicker extends ImagePicker {
  SelectionPicker(this.files, {this.beforeReturn});
  final List<XFile> files;
  final Future<void> Function()? beforeReturn;
  bool photosOnly = false;
  @override
  Future<List<XFile>> pickMultipleMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    await beforeReturn?.call();
    return files;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    photosOnly = true;
    await beforeReturn?.call();
    return files;
  }

  @override
  Future<XFile?> pickMedia({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
  }) async {
    await beforeReturn?.call();
    return files.firstOrNull;
  }
}

class SaveGate implements DraftRepository {
  SaveGate(this.delegate);
  final DraftRepository delegate;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    if (draft.shared.media.isNotEmpty) {
      if (!started.isCompleted) started.complete();
      await release.future;
      throw const LocalStorageException('Disk full');
    }
    await delegate.save(draft, expectedRevision: expectedRevision);
  }
}

void main() {
  test('picker journals original target before launch and saves durable media before acknowledgment', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final source = File('${File(s.database.db.path).parent.path}/photo.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
    final c = DraftController(sampleDraft(), s.drafts, s.clock);
    addTearDown(c.dispose);
    final picker = SelectionPicker(
      [XFile(source.path)],
      beforeReturn: () async {
        final operation = (await s.pickerImports.unresolved())!;
        expect(operation.draftId, c.draft.id);
        expect(operation.draftRevision, c.savedRevision);
        expect(operation.destination, Destination.instagram);
        expect((await s.drafts.get(c.draft.id))!.revision, c.savedRevision);
      },
    );
    expect(
      await pickDraftMedia(
        controller: c,
        media: s.media,
        pickerImports: s.pickerImports,
        canLaunchPicker: true,
        destination: Destination.instagram,
        picker: picker,
      ),
      isTrue,
    );
    expect(picker.photosOnly, isTrue);
    final saved = (await s.drafts.get(c.draft.id))!;
    expect(saved.shared.media, isEmpty);
    expect(saved.versions[Destination.instagram]!.ownText, isNull);
    final item = saved.versions[Destination.instagram]!.ownMedia!.single;
    expect(await (await s.media.fileFor(item.assetId)).exists(), isTrue);
    expect(await s.pickerImports.unresolved(), isNull);
  });

  test('failed replacement retains prior attachment and unresolved recovery journal', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final source = File('${File(s.database.db.path).parent.path}/photo.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
    final asset = await s.media.importFile(XFile(source.path));
    final initial = editSharedMedia(sampleDraft(), [
      Attachment(assetId: asset.id, altText: 'Keep description'),
    ], s.clock.now());
    final c = DraftController(initial, s.drafts, s.clock);
    addTearDown(c.dispose);
    await expectLater(
      pickDraftMedia(
        controller: c,
        media: s.media,
        pickerImports: s.pickerImports,
        canLaunchPicker: true,
        replacementAssetId: asset.id,
        picker: SelectionPicker([XFile('${source.path}.missing')]),
      ),
      throwsA(isA<Exception>()),
    );
    expect(c.draft.shared.media, initial.shared.media);
    expect(
      (await s.drafts.get(c.draft.id))!.shared.media,
      initial.shared.media,
    );
    expect((await s.pickerImports.unresolved())!.replacementAssetId, asset.id);
  });

  test('changed original draft refuses picker attachment without losing imported results', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final source = File('${File(s.database.db.path).parent.path}/photo.png');
    await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
    final c = DraftController(sampleDraft(), s.drafts, s.clock);
    addTearDown(c.dispose);
    await expectLater(
      pickDraftMedia(
        controller: c,
        media: s.media,
        pickerImports: s.pickerImports,
        canLaunchPicker: true,
        picker: SelectionPicker(
          [XFile(source.path)],
          beforeReturn: () async {
            c.change(editSharedCaption(c.draft, 'New words', s.clock.now()));
          },
        ),
      ),
      throwsStateError,
    );
    expect(c.draft.shared.media, isEmpty);
    expect(c.draft.shared.text, 'New words');
    expect((await s.pickerImports.unresolved())!.assets, hasLength(1));
  });

  test(
    'failed save never acknowledges a successfully imported selection',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final source = File('${File(s.database.db.path).parent.path}/photo.png');
      await source.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
      final repo = SaveGate(s.drafts);
      final c = DraftController(sampleDraft(), repo, s.clock);
      addTearDown(c.dispose);
      final pending = pickDraftMedia(
        controller: c,
        media: s.media,
        pickerImports: s.pickerImports,
        canLaunchPicker: true,
        picker: SelectionPicker([XFile(source.path)]),
      );
      await repo.started.future;
      expect((await s.pickerImports.unresolved())!.isComplete, isTrue);
      expect((await s.drafts.get(c.draft.id))!.shared.media, isEmpty);
      repo.release.complete();
      expect(await pending, isFalse);
      expect(await s.pickerImports.unresolved(), isNotNull);
    },
  );
}
