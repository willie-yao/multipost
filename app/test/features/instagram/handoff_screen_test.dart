import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/fake_android_transfer.dart';
import '../../support/instagram_fixture.dart';

void main() {
  testWidgets(
    'absent Instagram keeps gallery/caption fallback and no handoff',
    (tester) async {
      final transfer = FakeAndroidTransfer()
        ..launchResult = LaunchResult.unavailable;
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: transfer),
      ))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Full frozen caption'),
          operationId: 'launch',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Send photos to Instagram'), findsNothing);
      await tester.ensureVisible(find.text('Open Instagram'));
      await tester.tap(find.text('Open Instagram'));
      await settleEditor(tester);
      expect(find.textContaining('Open Instagram yourself'), findsOneWidget);
      expect(find.text('Copy caption'), findsOneWidget);
      expect(find.text('Save photos'), findsOneWidget);
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(package.id)))!
            .state,
        InstagramState.ready,
      );
      expect(
        await tester.runAsync(() => s.instagramRepo.events(package.id)),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('app return never repeats an explicit launch or sends photos', (
    tester,
  ) async {
    final transfer = FakeAndroidTransfer();
    final s = (await tester.runAsync(
      () => instagramTestServices(transfer: transfer),
    ))!;
    addTearDown(s.close);
    final package = (await tester.runAsync(
      () async => s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'launch',
      ),
    ))!;
    await tester.pumpWidget(
      CaptionApp(
        home: InstagramScreen(package: package, service: s.instagram),
      ),
    );
    await settleEditor(tester);
    await tester.ensureVisible(find.text('Open Instagram'));
    await tester.tap(find.text('Open Instagram'));
    await settleEditor(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleEditor(tester);
    expect(transfer.openCalls, 1);
    expect(transfer.sharedPackages, isEmpty);
    expect(
      (await tester.runAsync(() => s.instagramRepo.progress(package.id)))!
          .state,
      InstagramState.ready,
    );
    expect(find.textContaining('Instagram opened'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'a supported dispatch keeps caption copy separate and reports no publication proof',
    (tester) async {
      final transfer = FakeAndroidTransfer();
      final capability = InstagramShareCapability(
        carousel: true,
        checkedAt: DateTime.utc(2026),
        device: 'host fixture',
        instagramVersion: 'fixture only',
      );
      final s = (await tester.runAsync(
        () => instagramTestServices(
          transfer: transfer,
          shareCapability: capability,
        ),
      ))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Caption'),
          operationId: 'share',
        ),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Send photos to Instagram'));
      await tester.tap(find.text('Send photos to Instagram'));
      await settleEditor(tester);
      expect(find.textContaining('Photo share requested'), findsOneWidget);
      expect(
        find.textContaining('Publication is not verified'),
        findsOneWidget,
      );
      expect(transfer.copied, isNull);
      expect(find.text('Copy caption'), findsOneWidget);
      expect(
        (await tester.runAsync(() => s.instagramRepo.progress(package.id)))!
            .state,
        InstagramState.handedOff,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
