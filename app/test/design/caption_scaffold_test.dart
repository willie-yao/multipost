import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/design/caption_scaffold.dart';
import 'package:cross_posting_app/design/caption_text.dart';
import 'package:cross_posting_app/design/caption_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('large text leaves the next action reachable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CaptionScaffold(
            title: 'Your posts',
            body: const Text('Drafts are saved on this device.'),
            primaryAction: FilledButton(
              onPressed: () {},
              child: const Text('Create a draft'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Create a draft').hitTestable(), findsOneWidget);
  });

  // A fixed-height action or an unscrollable body would obscure content here.
  testWidgets('keyboard leaves a growing action and long content reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var pressed = false;
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
            padding: EdgeInsets.only(top: 24),
            viewPadding: EdgeInsets.only(top: 24, bottom: 24),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: CaptionScaffold(
            title: 'Your saved posts on this device',
            stageIndicator: const CaptionStageIndicator(currentStage: 2),
            actions: [
              IconButton(
                onPressed: () {},
                tooltip: 'More options',
                icon: const Icon(Icons.more_vert),
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 12; index++)
                  Text('Draft $index is saved on this device.'),
                const Text('Last draft'),
              ],
            ),
            primaryAction: FilledButton(
              onPressed: () => pressed = true,
              child: const Text('Continue to review your post'),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(FilledButton);
    expect(tester.getSize(button).height, greaterThan(52));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(360));
    await tester.ensureVisible(find.text('Last draft'));
    expect(find.text('Last draft').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(button);
    expect(pressed, isTrue);
  });

  // Without SafeArea the action would overlap Android's gesture area.
  testWidgets('action respects the system navigation inset', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 24, bottom: 24),
            viewPadding: EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: CaptionScaffold(
            title: 'Your posts',
            body: const Text('Drafts stay on this device.'),
            primaryAction: FilledButton(
              onPressed: () {},
              child: const Text('Create a draft'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      lessThanOrEqualTo(820),
    );
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(52),
    );
    expect(tester.takeException(), isNull);
  });

  // A screen without an action still owes its content the navigation safe area.
  testWidgets(
    'screen without an action keeps its last content above system UI',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const CaptionApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 24, bottom: 40),
              viewPadding: EdgeInsets.only(top: 24, bottom: 40),
            ),
            child: CaptionScaffold(
              title: 'Your posts',
              body: SizedBox(
                height: 1200,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('No more drafts'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('No more drafts'));
      expect(
        tester.getRect(find.text('No more drafts')).bottom,
        lessThanOrEqualTo(804),
      );
      expect(tester.takeException(), isNull);
    },
  );

  // Shrinking or clipping the steps would make the current stage unclear.
  testWidgets('stage labels reflow with a selected stage announcement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const CaptionApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CaptionScaffold(
            title: 'New post',
            stageIndicator: CaptionStageIndicator(currentStage: 2),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    // At 200% text the three tabs collapse to one line.
    expect(find.text('Step 2 of 3 · Write').hitTestable(), findsOneWidget);
    expect(find.text('1  Choose'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Step 2 of 3: Write')),
      matchesSemantics(
        label: 'Step 2 of 3: Write',
        isSelected: true,
        hasSelectedState: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // Per-word boxes would fragment the spoken caption and obstruct wrapping.
  testWidgets('captions wrap as continuous accessible text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const shared = 'A little color from today’s walk, saved for later.';
    const own = 'Poppies along the reservoir.';
    await tester.pumpWidget(
      const CaptionApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CaptionScaffold(
            title: 'Captions',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [CaptionText(shared), CaptionText(own, own: true)],
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text(shared)),
      matchesSemantics(label: shared, textDirection: TextDirection.ltr),
    );
    await tester.ensureVisible(find.text(own));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text(own)),
      matchesSemantics(label: own, textDirection: TextDirection.ltr),
    );
    expect(tester.getSize(find.text(shared)).height, greaterThan(84));
    expect(tester.takeException(), isNull);
  });

  // Ultramarine identifies destination-owned wording, not ordinary selection.
  testWidgets(
    'ordinary selection stays neutral while own captions stay ultramarine',
    (tester) async {
      await tester.pumpWidget(
        CaptionApp(
          home: CaptionScaffold(
            title: 'Caption',
            body: Column(
              children: [
                ChoiceChip(
                  label: const Text('Photos'),
                  selected: true,
                  onSelected: (_) {},
                ),
                const CaptionText('Own wording', own: true),
              ],
            ),
          ),
        ),
      );
      final label = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ChoiceChip),
          matching: find.byType(RichText),
        ),
      );
      expect(label.text.style?.color, CaptionTokens.light.onAction);
      expect(
        tester.widget<Text>(find.text('Own wording')).textSpan?.style?.color,
        CaptionTokens.light.own,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
