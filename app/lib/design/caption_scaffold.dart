import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'brand_mark.dart';
import 'caption_theme.dart';
import 'caption_tokens.dart';

class CaptionScaffold extends StatelessWidget {
  const CaptionScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.primaryAction,
    this.stageIndicator,
    this.actions = const [],
    this.bodyPadding = const EdgeInsets.all(16),
    this.showMark = false,
  });

  final String title;
  final Widget body;
  final Widget? leading;
  final Widget? primaryAction;
  final Widget? stageIndicator;
  final List<Widget> actions;
  final EdgeInsetsGeometry bodyPadding;

  /// Shows the brand mark before the title; used on the library only.
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: captionOverlay(context),
      child: Scaffold(
        backgroundColor: t.ground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: primaryAction == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          leading == null ? 16 : 4,
                          8,
                          actions.isEmpty ? 16 : 4,
                          8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (leading != null) ...[
                              leading!,
                              const SizedBox(width: 4),
                            ],
                            if (showMark) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 8, right: 12),
                                child: BrandMark(size: 32),
                              ),
                            ],
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                              ),
                            ),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ...actions,
                            ],
                          ],
                        ),
                      ),
                      if (stageIndicator != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: t.hairline),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: stageIndicator,
                          ),
                        ),
                      Padding(padding: bodyPadding, child: body),
                    ],
                  ),
                ),
              ),
              if (primaryAction != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.ground,
                    border: Border(top: BorderSide(color: t.hairline)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: compactChrome(context)
                        ? const EdgeInsets.fromLTRB(16, 6, 16, 6)
                        : const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: primaryAction,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only view of the current compose stage; navigation belongs to callers.
/// True when chrome should shrink: large text, or a short (landscape) screen.
bool compactChrome(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) > 24 ||
    MediaQuery.sizeOf(context).height < 500;

class CaptionStageIndicator extends StatelessWidget {
  const CaptionStageIndicator({
    super.key,
    required this.currentStage,
    this.onStep,
  }) : assert(currentStage >= 1 && currentStage <= 3);

  final int currentStage;

  /// Called with an earlier step (1-based) when it is tapped. Later steps are
  /// never tappable: each stage is reached by completing the one before it.
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    const labels = ['Choose', 'Write', 'Review'];
    // With large text or a short screen, one line instead of three tabs.
    if (compactChrome(context)) {
      return Semantics(
        container: true,
        label: 'Step $currentStage of 3: ${labels[currentStage - 1]}',
        selected: true,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Step $currentStage of 3 · ${labels[currentStage - 1]}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: t.text, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.spaceAround,
      spacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          Semantics(
            container: true,
            label: 'Step ${index + 1} of 3: ${labels[index]}',
            selected: currentStage == index + 1,
            button: onStep != null && index + 1 < currentStage,
            onTap: onStep != null && index + 1 < currentStage
                ? () => onStep!(index + 1)
                : null,
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onStep != null && index + 1 < currentStage
                    ? () => onStep!(index + 1)
                    : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: currentStage == index + 1
                              ? t.text
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Text(
                        '${index + 1}  ${labels[index]}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: currentStage == index + 1
                              ? t.text
                              : t.secondary,
                          fontWeight: currentStage == index + 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
