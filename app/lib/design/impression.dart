import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

/// How a state mark is impressed. Shape carries meaning together with the
/// word and icon, never colour alone:
/// filled = confirmed (by a provider, or by you); outline = waiting on you or
/// needs attention; dashed = unknown.
enum ImpressionTone { confirmed, attention, unknown, waiting, user }

/// A dated state mark: icon, word and optional time, e.g. "Published 21:14".
class ImpressionMark extends StatelessWidget {
  const ImpressionMark({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.time,
  });

  final String label;
  final ImpressionTone tone;
  final IconData? icon;
  final String? time;

  static IconData defaultIcon(ImpressionTone tone) => switch (tone) {
    ImpressionTone.confirmed => Icons.check,
    ImpressionTone.attention => Icons.error_outline,
    ImpressionTone.unknown => Icons.help_outline,
    ImpressionTone.waiting => Icons.radio_button_checked,
    ImpressionTone.user => Icons.person_outline,
  };

  /// The colour a tone's icon takes on its own (outside a mark).
  static Color iconColor(BuildContext context, ImpressionTone tone) {
    final t = CaptionTokens.of(context);
    return switch (tone) {
      ImpressionTone.confirmed => t.success,
      ImpressionTone.attention => t.error,
      ImpressionTone.unknown => t.warning,
      ImpressionTone.waiting || ImpressionTone.user => t.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final (Color fill, Color ink, Color edge) = switch (tone) {
      ImpressionTone.confirmed => (t.success, t.onSuccess, t.success),
      ImpressionTone.user => (t.text, t.ground, t.text),
      ImpressionTone.attention => (Colors.transparent, t.error, t.error),
      ImpressionTone.unknown => (Colors.transparent, t.warning, t.warning),
      ImpressionTone.waiting => (Colors.transparent, t.text, t.text),
    };
    final style = TextStyle(
      fontFamily: brandFace,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: ink,
    );
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon(tone), size: 18, color: ink),
          const SizedBox(width: 6),
          // A Wrap lets the time drop below the word at large text sizes.
          Flexible(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(label, style: style),
                if (time != null)
                  Text(
                    time!,
                    style: style.copyWith(
                      fontWeight: FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: time == null ? label : '$label, $time',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: tone == ImpressionTone.unknown
              ? CustomPaint(painter: _DashedEdge(edge), child: content)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(color: edge, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _DashedEdge extends CustomPainter {
  const _DashedEdge(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(6),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge old) => old.color != color;
}
