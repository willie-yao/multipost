import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  for (final own in [false, true]) {
    testWidgets(
      '${own ? 'Own version' : 'Shared composer'} reflows at 320dp and 200 percent with keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = await tester.runAsync(localTestServices);
        addTearDown(s!.close);
        final c = DraftController(
          editOwnCaption(
            sampleDraft(),
            Destination.bluesky,
            List.filled(6, 'A complete own caption.').join(' '),
            s.clock.now(),
          ),
          s.drafts,
          s.clock,
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          CaptionApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 280),
              ),
              child: own
                  ? VersionScreen(
                      controller: c,
                      destination: Destination.bluesky,
                      media: s.media,
                      pickerImports: s.pickerImports,
                      canLaunchPicker: true,
                    )
                  : WriteScreen(
                      controller: c,
                      media: s.media,
                      pickerImports: s.pickerImports,
                      canLaunchPicker: true,
                      onReview: () {},
                    ),
            ),
          ),
        );
        await settleEditor(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.text(own ? 'Done' : 'Review post').hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byType(TextField));
        expect(
          find.byType(TextField).hitTestable(at: const Alignment(0, -0.9)),
          findsOneWidget,
        );
        if (own) {
          await tester.ensureVisible(find.text('Use shared photos'));
          expect(find.text('Use shared photos').hitTestable(), findsOneWidget);
        } else {
          await tester.ensureVisible(find.text('Instagram'));
          expect(find.text('Instagram').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Back dismisses the keyboard before a saved editor route leaves',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
      final inset = ValueNotifier<double>(280);
      addTearDown(inset.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ValueListenableBuilder<double>(
                    valueListenable: inset,
                    builder: (context, bottom, _) => MediaQuery(
                      data: MediaQueryData(
                        viewInsets: EdgeInsets.only(bottom: bottom),
                      ),
                      child: WriteScreen(
                        controller: c,
                        media: s.media,
                        pickerImports: s.pickerImports,
                        canLaunchPicker: true,
                        onReview: () {},
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open writer'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open writer'));
      await settleEditor(tester);
      await tester.showKeyboard(find.byType(TextField));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Review post'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      inset.value = 0;
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settleEditor(tester);
      expect(find.text('Open writer'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
