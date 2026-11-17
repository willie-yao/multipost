import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/instagram_fixture.dart';
import '../../support/fake_android_transfer.dart';

void main() {
  testWidgets(
    'partial save, copy failure and rebuild keep cached integrity futures',
    (tester) async {
      final transfer = FakeAndroidTransfer(failOrdinals: {2})
        ..copyFailure = Exception('clipboard failed');
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: transfer),
      ))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Full frozen caption'),
          operationId: 'screen',
        ),
      ))!;
      final service = _CountingService(s, transfer);
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: service),
        ),
      );
      await settleEditor(tester);
      expect(service.reads, 2);
      await tester.ensureVisible(find.text('Copy caption'));
      await tester.tap(find.text('Copy caption'));
      await settleEditor(tester);
      expect(find.text('Retry copy'), findsOneWidget);
      expect(find.textContaining('could not be copied'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'Full frozen caption',
        ),
        findsOneWidget,
      );
      expect(service.reads, 2);
      transfer.copyFailure = null;
      await tester.tap(find.text('Retry copy'));
      await settleEditor(tester);
      expect(find.text('Caption copied'), findsOneWidget);
      expect(service.reads, 2);
      await tester.ensureVisible(find.text('Save photos'));
      await tester.tap(find.text('Save photos'));
      await settleEditor(tester);
      expect(find.text('1 of 2 saved'), findsOneWidget);
      expect(find.text('Retry remaining photo'), findsOneWidget);
      expect(find.text('Save photos'), findsNothing);
      final readsAfterSave = service.reads;
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: service),
        ),
      );
      await settleEditor(tester);
      expect(service.reads, readsAfterSave);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, hasLength(2));
      expect(images.every((w) => w.image is ResizeImage), isTrue);
      transfer.failOrdinals.clear();
      await tester.tap(find.text('Retry remaining photo'));
      await settleEditor(tester);
      expect(find.text('2 of 2 saved'), findsOneWidget);
      expect(transfer.savedBatches, [
        {1, 2},
        {2},
      ]);
      expect(
        find.textContaining('enter them inside Instagram'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'reopened package shows historical copy activity without reading clipboard',
    (tester) async {
      final transfer = FakeAndroidTransfer();
      final s = (await tester.runAsync(
        () => instagramTestServices(transfer: transfer),
      ))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(
        () async => s.instagram.prepare(
          await s.reviewTwoPhotos('Kept words'),
          operationId: 'copy-history',
        ),
      ))!;
      await tester.runAsync(() => s.instagram.copyCaption(package.id));
      await tester.pumpWidget(
        CaptionApp(
          home: InstagramScreen(package: package, service: s.instagram),
        ),
      );
      await settleEditor(tester);
      expect(
        find.text('Caption copied previously on this device'),
        findsOneWidget,
      );
      expect(transfer.savedBatches, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _CountingService extends InstagramService {
  _CountingService(InstagramTestServices s, FakeAndroidTransfer transfer)
    : super(
        s.instagramRepo,
        s.app.media,
        s.app.instagramPackageRoot,
        s.policy,
        s.app.ids,
        s.app.clock,
        transfer: transfer,
      );
  int reads = 0;
  @override
  Future<File> fileFor(InstagramPackage package, PreparedPhoto photo) {
    reads++;
    return super.fileFor(package, photo);
  }
}
