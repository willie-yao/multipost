import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/accounts_screen.dart';
import 'package:cross_posting_app/features/compose/choose_screen.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/review/review_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fixtures/acceptance_services.dart';
import 'fixtures/synthetic_video.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('R1 native synthetic visual and mixed-state acceptance', (
    tester,
  ) async {
    // Some emulator images lock the system night mode; a build with
    // --dart-define=CAPTURE_BRIGHTNESS=dark renders the same matrix dark.
    if (const String.fromEnvironment('CAPTURE_BRIGHTNESS') == 'dark') {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(binding.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    await captureNativeMatrix(
      tester,
      binding,
      await getApplicationSupportDirectory(),
    );
  });
}

// Also invoked once by local_recovery phase 0 so one prebuilt APK is sufficient.
Future<void> captureNativeMatrix(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Directory support,
) async {
  final visualParent = await Directory(p.join(support.path, 'r1-native-visual'))
      .create(recursive: true);
  final root = await visualParent.createTemp('batch-');
  final captures = await Directory(p.join(support.path, 'r1-native-captures'))
      .create(recursive: true);
  final x = NativePublisher(Destination.x, PublishStatus.published);
  final bluesky = NativePublisher(
    Destination.bluesky,
    PublishStatus.notPublished,
  );
  final app = await nativeFixture(
    root,
    providers: {Destination.x: x, Destination.bluesky: bluesky},
  );
  final controllers = <DraftController>[];
  var viewport = const Size(390, 844);
  var scale = 1.0;
  Future<void> show(Widget screen) async {
    await tester.pumpWidget(
      CaptionApp(
        key: UniqueKey(),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                size: viewport,
                textScaler: TextScaler.linear(scale),
                accessibleNavigation: true,
                disableAnimations: true,
              ),
              child: screen,
            ),
          ),
        ),
      ),
    );
    await nativeSettle(tester);
  }

  Future<void> capture(String name, {Finder? visibleTarget}) async {
    if (visibleTarget != null) {
      await Scrollable.ensureVisible(
        tester.element(visibleTarget),
        alignment: 0.5,
      );
    }
    // Scrolling can update layout before the native raster surface repaints.
    // Settle a fresh frame before screenshots, then assert the requested content
    // really is reachable inside this constrained viewport rather than naming a
    // duplicate initial frame as scrolled/action evidence.
    await nativeSettle(tester);
    await binding.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (visibleTarget != null) {
      expect(visibleTarget.hitTestable(), findsOneWidget);
      final rect = tester.getRect(visibleTarget);
      expect((Offset.zero & viewport).contains(rect.center), isTrue);
      debugPrint('R1 VISIBLE $name target=$rect; center is hit-testable');
    }
    expect(tester.takeException(), isNull);
    await File(p.join(captures.path, '$name.png'))
        .writeAsBytes(await binding.takeScreenshot(name));
    debugPrint(
      'R1 CAPTURE $name; ${viewport.width}x${viewport.height}dp text=$scale; widget-only after surface conversion',
    );
  }

  Future<DraftController> editor(Draft draft) async {
    await app.drafts.save(draft, expectedRevision: -1);
    final controller = DraftController(draft, app.drafts, app.clock);
    expect(await controller.flush(), isTrue);
    controllers.add(controller);
    return controller;
  }

  WriteScreen write(DraftController c) => WriteScreen(
    controller: c,
    media: app.media,
    pickerImports: app.pickerImports,
    canLaunchPicker: true,
    onReview: () {},
  );
  ReviewScreen review(DraftController c, {bool online = true}) => ReviewScreen(
    controller: c,
    service: app.review,
    observeOnline: () async => online,
    onConfirm: (_) async {},
    // The same callbacks the compose flow passes, so captures show its actions.
    onEdit: (_) async {},
    onChangeDestinations: () async {},
    onManageAccounts: () async {},
  );
  ResultsScreen results(String id) => ResultsScreen(
    groupId: id,
    attempts: app.attempts,
    coordinator: app.publishing,
    instagram: app.instagramRepo,
    onRetry: (_) async {},
    openExternal: (_, _) async => false,
  );
  try {
    await show(LibraryScreen(services: app));
    await File(p.join(captures.path, 'full-frame-ready'))
        .writeAsString('first-run', flush: true);
    debugPrint(
      'R1 STABLE FULL FRAME first-run; 15 second pre-conversion ADB capture window',
    );
    await Future<void>.delayed(const Duration(seconds: 15));
    await binding.convertFlutterSurfaceToImage();
    await capture('first-run-390-100');
    final empty = await editor(
      Draft(id: 'visual-empty', updatedAt: app.clock.now()),
    );
    await show(
      ChooseScreen(
        controller: empty,
        accounts: app.accounts,
        onContinue: () {},
      ),
    );
    await capture('choose-none-disconnected');
    await show(write(empty));
    await capture('write-empty');
    final media = <Attachment>[];
    for (var i = 0; i < 2; i++) {
      final asset = await app.media.importFile(await syntheticPhoto(root, i));
      media.add(
        Attachment(
          assetId: asset.id,
          altText: 'Bright synthetic photo ${i + 1}',
        ),
      );
    }
    await connectNativeFixtures(app);
    final longText = List.filled(
      3,
      'A little color from today’s walk. 🌻 日本語 العربية — kept exactly as typed.',
    ).join('\n');
    final composing = await editor(
      Draft(
        id: 'visual-composer',
        updatedAt: app.clock.now(),
        stage: ComposeStage.write,
        selected: Destination.values.toSet(),
        shared: PostContent(text: longText, media: media),
        versions: {
          Destination.bluesky: DestinationVersion(
            ownText: 'My own version 🌻 日本語 العربية',
          ),
        },
      ),
    );
    await show(write(composing));
    await capture('write-bright-photos');
    await capture(
      'write-long-multilingual',
      visibleTarget: find.widgetWithText(TextField, 'Shared caption'),
    );
    final videoSource = File(p.join(root.path, 'synthetic-video.mp4'));
    await videoSource.writeAsBytes(base64Decode(syntheticVideoBase64));
    final video = await app.media.importFile(XFile(videoSource.path));
    final videoEditor = await editor(
      Draft(
        id: 'visual-video',
        updatedAt: app.clock.now(),
        stage: ComposeStage.write,
        selected: {Destination.x, Destination.bluesky},
        shared: PostContent(
          text: 'Synthetic video',
          media: [Attachment(assetId: video.id)],
        ),
      ),
    );
    await show(write(videoEditor));
    await capture('write-video');
    await show(
      VersionScreen(
        controller: composing,
        destination: Destination.bluesky,
        media: app.media,
        pickerImports: app.pickerImports,
        canLaunchPicker: true,
      ),
    );
    await capture('own-version');
    await tester.ensureVisible(find.text('Compare captions'));
    await tester.tap(find.text('Compare captions'));
    await nativeSettle(tester);
    await capture('own-comparison');
    await tester.tap(find.text('Close comparison'));
    await nativeSettle(tester);
    await tester.ensureVisible(find.text('Shared caption'));
    await tester.tap(find.text('Shared caption'));
    await nativeSettle(tester);
    await capture('own-reset-dialog');
    await tester.tap(find.text('Keep own caption'));
    await nativeSettle(tester);
    await show(review(composing));
    await capture('review-valid-long');
    await show(review(composing, online: false));
    await capture('review-offline');
    await show(review(empty));
    await capture('review-blocked');
    Future<void> accounts(AccountState a, AccountState b, String name) async {
      await app.accounts.setState(Destination.x, a);
      await app.accounts.setState(Destination.bluesky, b);
      await show(
        AccountsScreen(
          accounts: app.accounts,
          connections: {
            Destination.x: _NoExternalConnection(),
            Destination.bluesky: _NoExternalConnection(),
          },
        ),
      );
      await capture(name);
    }

    await accounts(
      AccountState.connecting,
      AccountState.expired,
      'accounts-connecting-expired',
    );
    await accounts(
      AccountState.repairRequired,
      AccountState.removalPending,
      'accounts-repair-removal',
    );
    await connectNativeFixtures(app);
    Future<String> makeGroup(String id) async {
      final draft = Draft(
        id: id,
        updatedAt: app.clock.now(),
        selected: Destination.values.toSet(),
        shared: PostContent(
          text: 'Synthetic mixed results 🌻 日本語 العربية',
          media: media,
        ),
        versions: {
          Destination.x: DestinationVersion(ownMedia: []),
          Destination.bluesky: DestinationVersion(
            ownText: 'Bluesky own caption',
          ),
        },
      );
      await app.drafts.save(draft, expectedRevision: -1);
      final checked = await app.review.review(draft, directOnline: true);
      expect(checked.canProceed, isTrue);
      return app.publishing.confirm(checked.snapshot, operationId: id);
    }

    final partial = await makeGroup('visual-partial');
    await show(results(partial));
    await capture('results-partial-bright-later-photo');
    await show(LibraryScreen(services: app));
    await capture('library-attention-first');
    bluesky.status = PublishStatus.processing;
    final processing = await makeGroup('visual-processing');
    await show(results(processing));
    await capture('results-processing');
    bluesky.status = PublishStatus.unknown;
    final unknown = await makeGroup('visual-unknown');
    await show(results(unknown));
    await capture('results-unknown');
    await capture(
      'results-unknown-actions',
      visibleTarget: find.text('Send again…'),
    );
    final leaf = (await app.attempts.effectiveAttempts(unknown)).last;
    await app.publishing.reportFound(leaf.id);
    await show(results(unknown));
    await capture('results-user-report');
    final prepared = (await app.attempts.instagramPreparation(partial))!;
    final package = (await app.instagramRepo.get(prepared.packageId!))!;
    await show(InstagramScreen(package: package, service: app.instagram));
    await capture('instagram-ready');
    await app.instagram.markPosted(package.id);
    await show(InstagramScreen(package: package, service: app.instagram));
    await capture('instagram-marked');
    await app.instagram.undoMarked(package.id);
    await show(InstagramScreen(package: package, service: app.instagram));
    await capture('instagram-undo');
    viewport = const Size(320, 844);
    scale = 2;
    await show(write(composing));
    await capture('write-320-200');
    await capture(
      'write-long-320-200',
      visibleTarget: find.widgetWithText(TextField, 'Shared caption'),
    );
    await show(review(composing));
    await capture('review-320-200');
    await show(results(partial));
    await capture('results-320-200');
    await accounts(
      AccountState.repairRequired,
      AccountState.removalPending,
      'accounts-recovery-320-200',
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    viewport = const Size(720, 320);
    await show(write(composing));
    await capture('write-landscape-200');
    await capture(
      'write-long-landscape-200',
      visibleTarget: find.widgetWithText(TextField, 'Shared caption'),
    );
    await show(review(composing));
    await capture('review-landscape-200');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(x.sends, 3);
    expect(bluesky.sends, 3);
    debugPrint(
      'R1 mixed matrix complete: fake sends only; no external URLs, provider/accounts, gallery export or Instagram receiving app used.',
    );
  } finally {
    await SystemChrome.setPreferredOrientations([]);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in controllers) {
      controller.dispose();
    }
    await app.close();
    await root.delete(recursive: true);
  }
}

class _NoExternalConnection implements AccountConnection {
  @override
  Future<AccountIdentity> connect({String? handle}) async =>
      throw StateError('No external authorization in this fixture');
  @override
  Future<void> disconnect() async => throw StateError('Capture fixture only');
  @override
  Future<void> repairCredentials() async =>
      throw StateError('Capture fixture only');
  @override
  Future<void> ensureAuthorized() async =>
      throw StateError('Capture fixture only');
}
