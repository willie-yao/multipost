import 'dart:async';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/fake_android_transfer.dart';
import '../../support/instagram_fixture.dart';

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'explicit confirmation cancels, restores focus, then marks once and offers persistent Undo',
    (tester) async {
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: FakeAndroidTransfer()),
      ))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: p, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Open Instagram'));
      await tester.tap(find.text('Open Instagram'));
      await settleEditor(tester);
      final manual = find.text("I've posted it");
      await tester.ensureVisible(manual);
      final callback = tester
          .widget<TextButton>(find.widgetWithText(TextButton, "I've posted it"))
          .onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(p.id)))!.state,
        InstagramState.ready,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, "I've posted it"),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.tap(manual);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as posted'));
      await settleEditor(tester);
      expect(find.text('Marked posted'), findsOneWidget);
      expect(find.textContaining('Instagram opened.'), findsNothing);
      expect(find.textContaining('Your confirmation at'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      final messenger = tester.state<ScaffoldMessengerState>(
        find.byType(ScaffoldMessenger),
      );
      messenger.removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Undo my confirmation'));
      await tester.tap(find.text('Undo my confirmation'));
      await settleEditor(tester);
      expect(find.text('Ready to share'), findsOneWidget);
      expect(
        (await tester.runAsync(() => s.instagramRepo.events(p.id)))!
            .where((e) => e.kind == InstagramEventKind.markedPosted),
        hasLength(1),
      );
      expect(
        await tester.runAsync(() => s.instagram.fileFor(p, p.photos.last)),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'pause and resume before native completion prompt once without changing publication state',
    (tester) async {
      final transfer = _DelayedLaunch();
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: transfer),
      ))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: p, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Open Instagram'));
      await tester.tap(find.text('Open Instagram'));
      await tester.runAsync(() => transfer.entered.future);
      _leave(tester);
      _return(tester);
      await tester.pump();
      transfer.gate.complete(LaunchResult.opened);
      await settleEditor(tester);
      expect(
        find.text('Back from Instagram. Did you finish posting?'),
        findsOneWidget,
      );
      expect(find.text('Status: still Ready to share'), findsOneWidget);
      expect(find.textContaining('Instagram opened.'), findsNothing);
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(p.id)))!.state,
        InstagramState.ready,
      );
      expect(
        (await tester.runAsync(() => s.instagramRepo.events(p.id)))!
            .where((e) => e.kind == InstagramEventKind.returnAcknowledged),
        hasLength(1),
      );
      await tester.ensureVisible(find.text('Not yet'));
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      _leave(tester);
      _return(tester);
      await settleEditor(tester);
      expect(
        find.text('Back from Instagram. Did you finish posting?'),
        findsNothing,
      );
      expect(find.text("I've posted it"), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'chooser return is honest and an unrelated later background trip cannot reuse an unobserved launch',
    (tester) async {
      final transfer = _ShareEntry()..shareResult = ShareDispatch.chooserOpened;
      final s = (await tester.runAsync(
        () => instagramTestServices(
          transfer: transfer,
          shareCapability: InstagramShareCapability(
            carousel: true,
            checkedAt: DateTime.utc(2026),
            device: 'synthetic',
            instagramVersion: 'fixture only',
          ),
        ),
      ))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: p, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Open Instagram'));
      await tester.tap(find.text('Open Instagram'));
      await settleEditor(tester);
      _leave(tester);
      _return(tester);
      await settleEditor(tester);
      expect(find.text('Not yet'), findsNothing);
      await tester.ensureVisible(find.text('Send photos to Instagram'));
      transfer.onShare = () {
        _leave(tester);
        _return(tester);
      };
      await tester.tap(find.text('Send photos to Instagram'));
      await settleEditor(tester);
      expect(find.text('Back to your post'), findsOneWidget);
      expect(
        find.text('Back from Instagram. Did you finish posting?'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'marked package stays in Your posts after restart and draft deletion so Undo is reachable',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(() async {
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Kept package'),
          operationId: 'p',
        );
        await s.instagram.markPosted(p.id);
        await s.app.drafts.setDeleted(p.draftId, s.app.clock.now());
        await s.app.database.db.delete(
          'drafts',
          where: 'id = ?',
          whereArgs: [p.draftId],
        );
        return p;
      }))!;
      final restarted = (await tester.runAsync(() async {
        final path = s.app.database.db.path;
        await s.app.database.close();
        final database = await LocalDatabase.open(
          databaseFactoryFfiNoIsolate,
          path,
        );
        final media = MediaFiles(database, s.app.media.root, s.app.ids);
        return AppServices(
          database: database,
          media: media,
          drafts: SqliteDraftRepository(database, media: media),
          accounts: LocalAccountRepository(database),
          clock: s.app.clock,
          ids: s.app.ids,
          instagramPackageRoot: s.app.instagramPackageRoot,
        );
      }))!;
      addTearDown(restarted.close);
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: restarted)),
      );
      await settleEditor(tester);
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Instagram record'));
      await tester.tap(find.text('View Instagram record'));
      await settleEditor(tester);
      expect(find.text('Marked posted'), findsOneWidget);
      await tester.ensureVisible(find.text('Undo my confirmation'));
      await tester.tap(find.text('Undo my confirmation'));
      await settleEditor(tester);
      expect(
        (await tester.runAsync(() => restarted.instagramRepo.progress(p.id)))!
            .state,
        InstagramState.ready,
      );
      expect(
        await tester.runAsync(
          () => restarted.instagram.fileFor(p, p.photos.last),
        ),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed gallery recheck cannot hide persistent confirmation correction',
    (tester) async {
      final transfer = _FailingRecheck();
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: transfer),
      ))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(() async {
        final p = await s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        );
        await s.instagram.saveMissingPhotos(p.id);
        await s.instagram.markPosted(p.id);
        transfer.fail = true;
        return p;
      }))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: p, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Marked posted'), findsOneWidget);
      expect(find.text('2 of 2 saved'), findsNothing);
      await tester.tap(find.text('Undo my confirmation'));
      await settleEditor(tester);
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(p.id)))!.state,
        InstagramState.ready,
      );
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(p.id)))!
            .savedUris,
        hasLength(2),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'confirmation dialog reflows at 320dp and 200 percent with accessible actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final p = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'p',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              accessibleNavigation: true,
            ),
            child: InstagramScreen(package: p, service: s.instagram),
          ),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text("I've posted it"));
      await tester.tap(find.text("I've posted it"));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mark as posted'));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text('Mark as posted'));
      await settleEditor(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Undo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}

class _DelayedLaunch extends FakeAndroidTransfer {
  final entered = Completer<void>();
  final gate = Completer<LaunchResult>();
  @override
  Future<LaunchResult> openInstagram() {
    entered.complete();
    return gate.future;
  }
}

class _ShareEntry extends FakeAndroidTransfer {
  void Function()? onShare;
  @override
  Future<ShareDispatch> sharePhotos(InstagramPackage package) {
    onShare?.call();
    return super.sharePhotos(package);
  }
}

void _leave(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _return(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

class _FailingRecheck extends FakeAndroidTransfer {
  bool fail = false;
  @override
  Future<List<PhotoSaveResult>> reconcilePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) {
    if (fail) throw StateError('synthetic native availability failure');
    return super.reconcilePhotos(package, jobs);
  }
}
