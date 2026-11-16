import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

class CaptionScaffold extends StatelessWidget {
  const CaptionScaffold({
    super.key,
    required this.title,
    required this.body,
    this.primaryAction,
    this.stageIndicator,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final Widget? primaryAction;
  final Widget? stageIndicator;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    ColoredBox(
                      color: CaptionTokens.stage,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                    if (stageIndicator != null)
                      ColoredBox(
                        color: CaptionTokens.stage,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: stageIndicator,
                        ),
                      ),
                    Padding(padding: const EdgeInsets.all(16), child: body),
                  ],
                ),
              ),
            ),
            if (primaryAction != null)
              ColoredBox(
                color: CaptionTokens.stage,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: primaryAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A read-only view of the current compose stage; navigation belongs to callers.
class CaptionStageIndicator extends StatelessWidget {
  const CaptionStageIndicator({super.key, required this.currentStage})
    : assert(currentStage >= 1 && currentStage <= 3);

  final int currentStage;

  @override
  Widget build(BuildContext context) {
    const labels = ['Choose', 'Write', 'Review'];
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          Semantics(
            container: true,
            label: 'Step ${index + 1} of 3: ${labels[index]}',
            selected: currentStage == index + 1,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: currentStage == index + 1
                          ? CaptionTokens.text
                          : CaptionTokens.stage,
                      width: 3,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    '${index + 1}  ${labels[index]}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: currentStage == index + 1
                          ? CaptionTokens.text
                          : CaptionTokens.secondary,
                      fontWeight: currentStage == index + 1
                          ? FontWeight.w700
                          : FontWeight.w500,
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
