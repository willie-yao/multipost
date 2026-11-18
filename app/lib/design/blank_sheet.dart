import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

/// The empty-drafts picture: a blank post sheet with today's date already
/// stamped on it, as every outcome in the app is a dated impression.
/// Decorative only; the heading beside it carries the meaning.
class BlankSheetArt extends StatelessWidget {
  const BlankSheetArt({super.key, required this.today});
  final DateTime today;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    Widget bar(double widthFactor) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: t.raised,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
    final stamp = Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
      decoration: BoxDecoration(
        border: Border.all(color: t.text.withValues(alpha: 0.72), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${today.day}',
            style: TextStyle(
              fontFamily: brandFace,
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w700,
              color: t.text.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _months[today.month - 1],
            style: TextStyle(
              fontFamily: brandFace,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: t.text.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
                decoration: BoxDecoration(
                  color: t.sheet,
                  border: Border.all(color: t.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: t.raised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          bar(1),
                          const SizedBox(height: 10),
                          bar(0.82),
                          const SizedBox(height: 10),
                          bar(0.5),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 18,
                bottom: 14,
                child: Transform.rotate(
                  angle: -0.12,
                  child: still
                      ? stamp
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.scale(
                              scale: 1.18 - 0.18 * v,
                              child: child,
                            ),
                          ),
                          child: stamp,
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
