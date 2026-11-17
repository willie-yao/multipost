import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/compose/choose_screen.dart';
import 'package:cross_posting_app/features/compose/draft_session.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/media/media_editor_screen.dart';
import 'package:cross_posting_app/features/media/photo_transform_screen.dart';
import 'package:cross_posting_app/features/media/picker_imports.dart';
import 'package:cross_posting_app/main.dart' as app_main;
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_fixture.dart';
import '../support/draft_fixtures.dart';
import '../support/instagram_fixture.dart';

const _private = 'synthetic-private-caption-token-key-path';
PlatformException _rawError() => PlatformException(
  code: 'failed',
  message: _private,
  details: 'https://example.invalid/callback?access_token=$_private',
);

void main() {
  testWidgets(
    'browsing saved library does not use network or read the clipboard',
    (tester) async {
      final s = (await tester.runAsync(localTestServices))!;
      addTearDown(s.close);
      await tester.runAsync(
        () => s.drafts.save(sampleDraft(), expectedRevision: -1),
      );
      var networkClients = 0;
      var clipboardReads = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') clipboardReads++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
          await settleEditor(tester);
          expect(find.text(sampleDraft().shared.text), findsOneWidget);
          await tester.tap(find.text('Results'));
          await settleEditor(tester);
          await tester.tap(find.text('Drafts'));
          await settleEditor(tester);
        },
        createHttpClient: (_) {
          networkClients++;
          throw StateError('Library must remain local');
        },
      );
      expect(networkClients, 0);
      expect(clipboardReads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('bootstrap failure never displays platform payloads', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => throw _rawError());
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    // Establish this test's frame epoch before main schedules a warm-up frame.
    await tester.pumpWidget(const SizedBox.shrink());
    app_main.main();
    await settleEditor(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining(_private), findsNothing);
  });

  for (final error in <Object>[_rawError(), const DraftConflict(_private)]) {
    testWidgets(
      'failed save keeps unsaved recovery and safe ${error.runtimeType} detail',
      (tester) async {
        final s = (await tester.runAsync(localTestServices))!;
        addTearDown(s.close);
        final initial = sampleDraft();
        await tester.runAsync(
          () => s.drafts.save(initial, expectedRevision: -1),
        );
        final controller = DraftController(
          initial,
          _FailedSave(s.drafts, error),
          s.clock,
        );
        addTearDown(controller.dispose);
        controller.change(
          editSharedCaption(initial, 'Unsaved words', s.clock.now()),
        );
        expect(await controller.flush(), isFalse);
        await tester.pumpWidget(
          CaptionApp(
            home: DraftSession(
              controller: controller,
              child: const Text('Editor'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text("Couldn't save — keep this screen open"),
          findsOneWidget,
        );
        expect(find.text('Copy text'), findsOneWidget);
        expect(find.text('Retry saving'), findsOneWidget);
        expect(find.textContaining(_private), findsNothing);
        expect(
          find.textContaining('Your saved work is still available'),
          findsNothing,
        );
        expect(
          (await tester.runAsync(() => s.drafts.get(initial.id)))!.shared.text,
          initial.shared.text,
        );
        if (error is DraftConflict) {
          expect(find.text(error.toString()), findsOneWidget);
          expect(find.text('Reload saved draft'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'destination load failure hides private payloads without claiming unsaved text is durable',
    (tester) async {
      final s = (await tester.runAsync(localTestServices))!;
      addTearDown(s.close);
      final controller = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: ChooseScreen(
            controller: controller,
            accounts: _FailedAccounts(s),
            onContinue: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining(_private), findsNothing);
      expect(
        find.textContaining('Your saved work is still available'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('library load failure hides private payloads', (tester) async {
    final s = (await tester.runAsync(localTestServices))!;
    addTearDown(s.close);
    await tester.pumpWidget(
      CaptionApp(home: LibraryScreen(services: _FailedLibrary(s))),
    );
    await settleEditor(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining(_private), findsNothing);
  });

  testWidgets(
    'library picker recovery hides private platform details and retains repair',
    (tester) async {
      final s = (await tester.runAsync(localTestServices))!;
      addTearDown(s.close);
      s.pickerRecoveryError = _rawError();
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
      await settleEditor(tester);
      expect(find.text('Retry media recovery'), findsOneWidget);
      expect(find.textContaining(_private), findsNothing);
    },
  );

  testWidgets(
    'media selection failure hides unknown payloads and keeps the editor',
    (tester) async {
      final s = (await tester.runAsync(localTestServices))!;
      addTearDown(s.close);
      final controller = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaEditorScreen(
            items: const [],
            media: s.media,
            onChanged: (_) {},
            controller: controller,
            pickerImports: _FailedImports(s),
            canLaunchPicker: true,
          ),
        ),
      );
      await settleEditor(tester);
      await tester.tap(find.text('Add media'));
      await settleEditor(tester);
      expect(find.textContaining(_private), findsNothing);
      expect(
        find.textContaining('Your saved work is still available'),
        findsNothing,
      );
      expect(find.text('Add media'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final error in <Object>[
    _rawError(),
    const MediaFileException('This media item is missing.'),
  ]) {
    testWidgets('photo load uses safe ${error.runtimeType} copy', (
      tester,
    ) async {
      final s = (await tester.runAsync(localTestServices))!;
      addTearDown(s.close);
      await tester.pumpWidget(
        CaptionApp(
          home: PhotoTransformScreen(
            attachment: const Attachment(assetId: 'missing'),
            media: _FailedMedia(s, error),
            crop: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(_private), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save crop'),
            )
            .onPressed,
        isNull,
      );
      if (error is MediaFileException) {
        expect(find.text(error.message), findsOneWidget);
      }
    });
  }

  testWidgets(
    'prepared-photo error hides unexpected file details and keeps retry',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(() async {
        final reviewed = await s.reviewTwoPhotos('Kept prepared caption');
        return s.instagram.prepare(reviewed, operationId: 'private-error');
      }))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: _FailedInstagram(s)),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Retry photo check'), findsNWidgets(2));
      expect(find.textContaining(_private), findsNothing);
    },
  );
}

class _FailedSave implements DraftRepository {
  _FailedSave(this.delegate, this.error);
  final DraftRepository delegate;
  final Object error;
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async =>
      throw error;
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
}

class _FailedAccounts extends LocalAccountRepository {
  _FailedAccounts(AppServices app) : super(app.database);
  @override
  Future<List<AccountView>> list() async => throw _rawError();
}

class _FailedLibrary extends AppServices {
  _FailedLibrary(AppServices app)
    : super(
        database: app.database,
        media: app.media,
        drafts: app.drafts,
        accounts: app.accounts,
        clock: app.clock,
        ids: app.ids,
        instagramPackageRoot: app.instagramPackageRoot,
      );
  @override
  Future<void> refreshPicker() async => throw _rawError();
}

class _FailedImports extends PickerImports {
  _FailedImports(AppServices app) : super(app.media, app.ids);
  @override
  Future<PickerImportOperation> begin({
    required String draftId,
    required int draftRevision,
    Destination? destination,
    String? replacementAssetId,
  }) async => throw _rawError();
}

class _FailedMedia extends MediaFiles {
  _FailedMedia(AppServices app, this.error)
    : super(app.database, app.media.root, app.ids);
  final Object error;
  @override
  Future<MediaAsset?> find(String id) async => throw error;
}

class _FailedInstagram extends InstagramService {
  _FailedInstagram(InstagramTestServices s)
    : super(
        s.instagramRepo,
        s.app.media,
        s.app.instagramPackageRoot,
        s.policy,
        s.app.ids,
        s.app.clock,
      );
  @override
  Future<File> fileFor(InstagramPackage package, PreparedPhoto photo) async =>
      throw _rawError();
}
