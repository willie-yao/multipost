import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/fake_android_transfer.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('I4 native Flutter UI with synthetic transfer/lifecycle only', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    // Unique private fixture: never reset existing app or gallery records.
    final fixtureParent = await Directory(p.join(support.path, 'i4-fixtures'))
        .create(recursive: true);
    final root = await fixtureParent.createTemp('confirmation-');
    final database = await LocalDatabase.open(
      databaseFactory,
      p.join(root.path, 'test.db'),
    );
    final media = MediaFiles(
      database,
      Directory(p.join(root.path, 'media')),
      const Ids(),
    );
    final services = AppServices(
      database: database,
      media: media,
      drafts: SqliteDraftRepository(database, media: media),
      accounts: LocalAccountRepository(database),
      clock: const Clock(),
      ids: const Ids(),
      instagramPackageRoot: Directory(p.join(root.path, 'instagram-packages')),
    );
    final transfer = _SyntheticTripTransfer(binding);
    final service = InstagramService(
      services.instagramRepo,
      media,
      services.instagramPackageRoot,
      services.instagramPolicy,
      services.ids,
      services.clock,
      transfer: transfer,
    );
    final attachments = <Attachment>[];
    for (var i = 0; i < 2; i++) {
      final photo = img.Image(width: 320, height: 240);
      img.fill(
        photo,
        color: i == 0 ? img.ColorRgb8(0, 115, 145) : img.ColorRgb8(15, 70, 32),
      );
      img.fillCircle(
        photo,
        x: i == 0 ? 110 : 210,
        y: 120,
        radius: 65,
        color: i == 0
            ? img.ColorRgb8(246, 199, 53)
            : img.ColorRgb8(43, 149, 77),
      );
      final file = File(p.join(root.path, 'synthetic-$i.png'));
      await file.writeAsBytes(img.encodePng(photo));
      final asset = await media.importFile(XFile(file.path));
      attachments.add(
        Attachment(assetId: asset.id, altText: 'Synthetic photo ${i + 1}'),
      );
    }
    final draft = Draft(
      id: services.ids.next(),
      updatedAt: services.clock.now(),
      selected: {Destination.instagram},
      shared: PostContent(
        text: "A little color from today's walk. The city always leaves something worth noticing.",
        media: attachments,
      ),
    );
    await services.drafts.save(draft, expectedRevision: -1);
    final reviewed = await services.review.review(draft);
    expect(reviewed.canProceed, isTrue);
    final package = await service.prepare(
      reviewed.snapshot,
      operationId: 'native-i4',
    );
    await tester.pumpWidget(
      CaptionApp(
        home: InstagramScreen(package: package, service: service),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 200 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await tester.pumpAndSettle();
      expect(
        condition(),
        isTrue,
        reason: 'Bounded native IO/frame wait expired.',
      );
    }

    await waitFor(() => find.text('Working…').evaluate().isEmpty);

    await binding.convertFlutterSurfaceToImage();
    Future<void> capture(String state) async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await File(p.join(support.path, 'i4-$state.png'))
          .writeAsBytes(await binding.takeScreenshot('i4-$state'));
      debugPrint('I4 CAPTURE $state');
    }

    await capture('ready');
    await tester.ensureVisible(find.text('Open Instagram'));
    await tester.tap(find.text('Open Instagram'));

    await waitFor(
      () =>
          find
              .text('Back from Instagram. Did you finish posting?')
              .evaluate()
              .isNotEmpty &&
          find.text('Working…').evaluate().isEmpty,
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await capture('return');
    await tester.tap(find.widgetWithText(FilledButton, "I've posted it"));
    await tester.pumpAndSettle();
    await capture('dialog');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "I've posted it"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as posted'));
    await waitFor(
      () =>
          find.text('Marked posted').evaluate().isNotEmpty &&
          find.text('Working…').evaluate().isEmpty,
    );
    expect(
      (await services.instagramRepo.progress(package.id)).state,
      InstagramState.userMarked,
    );
    await capture('marked');
    ScaffoldMessenger.of(tester.element(find.byType(InstagramScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo my confirmation'));
    await waitFor(
      () =>
          find.text('Status: still Ready to share').evaluate().isNotEmpty &&
          find.text('Working…').evaluate().isEmpty,
    );
    expect(
      (await services.instagramRepo.progress(package.id)).state,
      InstagramState.ready,
    );
    expect(
      await (await service.fileFor(package, package.photos.last)).exists(),
      isTrue,
    );
    await capture('undo');
    // The test runner may replace this view when the test finishes.
    ScaffoldMessenger.of(tester.element(find.byType(InstagramScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    debugPrint(
      'I4 synthetic UI state checks passed; no Instagram receiving-app evidence. Fixture=${root.path}',
    );
  });
}

class _SyntheticTripTransfer extends FakeAndroidTransfer {
  _SyntheticTripTransfer(this.binding);
  final IntegrationTestWidgetsFlutterBinding binding;

  @override
  Future<LaunchResult> openInstagram() {
    // Inject only at transfer entry, after local validation. This is synthetic
    // lifecycle evidence for app UI; Instagram is not installed or exercised.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    return super.openInstagram();
  }
}
