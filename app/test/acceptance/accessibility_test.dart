import 'dart:ui' as ui;

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_fixture.dart';

void main() {
  for (final size in [const Size(320, 720), const Size(720, 320)]) {
    testWidgets(
      'first run and Choose remain operable at $size and 200 percent text',
      (tester) async {
        final services = (await tester.runAsync(localTestServices))!;
        addTearDown(services.close);
        final semantics = tester.ensureSemantics();

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          CaptionApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
                accessibleNavigation: true,
                disableAnimations: true,
              ),
              child: LibraryScreen(services: services),
            ),
          ),
        );
        await settleEditor(tester);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.ensureVisible(find.text('Create a draft'));
        await tester.tap(find.text('Create a draft'));
        await settleEditor(tester);
        expect(find.text('Where should this go?'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Back'));
        expect(
          tester.getRect(find.byTooltip('Back')).left,
          lessThan(tester.getRect(find.text('New post')).left),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('choose-instagram')),
        );
        await tester.tap(find.byKey(const ValueKey('choose-instagram')));
        await settleEditor(tester);
        await tester.ensureVisible(find.text('Continue to writing'));
        expect(find.text('Continue to writing').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'first run paints a full-width black stage into the real top inset',
    (tester) async {
      final services = (await tester.runAsync(localTestServices))!;
      addTearDown(services.close);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: CaptionApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 28),
                viewPadding: EdgeInsets.only(top: 28),
              ),
              child: LibraryScreen(services: services),
            ),
          ),
        ),
      );
      await settleEditor(tester);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final pixels = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      void blackAt(int x, int y) {
        final offset = (y * image.width + x) * 4;
        expect(pixels.buffer.asUint8List(offset, 3), [
          0,
          0,
          0,
        ], reason: 'Rendered stage at $x,$y');
      }

      blackAt(5, 5);
      final hero = tester.getRect(find.text('Review each destination.'));
      blackAt(0, hero.center.dy.round());
      blackAt(389, hero.center.dy.round());
      image.dispose();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
