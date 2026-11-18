import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

/// Fixed brand colours for the mark; they do not follow the light/dark scheme.
const markInk = Color(0xFF2B3BC9);
const markPaper = Color(0xFFFFFFFF);

/// The Multipost mark: a ditto sign ("the same again") over a ruled line,
/// drawn on the adaptive-icon grid (108 units, 66-unit safe zone). It does not
/// depend on the working name, so a rename only swaps the wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: CustomPaint(
        size: Size.square(size),
        painter: const _MarkPainter(background: markInk, ink: markPaper),
      ),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.background, required this.ink});
  final Color background, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 10 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(48.5 * s, 38.5 * s), Offset(42.5 * s, 59.5 * s), stroke)
      ..drawLine(Offset(65.5 * s, 38.5 * s), Offset(59.5 * s, 59.5 * s), stroke)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(35 * s, 67.5 * s, 38 * s, 7 * s),
          Radius.circular(3.5 * s),
        ),
        Paint()..color = ink,
      );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.background != background || old.ink != ink;
}

/// The small ditto sign that labels a destination using the shared caption.
/// Decorative: the adjacent words "Shared caption" carry the meaning.
class DittoGlyph extends StatelessWidget {
  const DittoGlyph({super.key, this.color, this.size = 16});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(size * 0.9, size),
      painter: _DittoPainter(color ?? CaptionTokens.of(context).secondary),
    ),
  );
}

class _DittoPainter extends CustomPainter {
  const _DittoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = h * 0.16
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(w * 0.42, h * 0.2), Offset(w * 0.22, h * 0.78), stroke)
      ..drawLine(Offset(w * 0.86, h * 0.2), Offset(w * 0.66, h * 0.78), stroke);
  }

  @override
  bool shouldRepaint(_DittoPainter old) => old.color != color;
}

/// Mark plus wordmark. "Multipost" is a temporary working name.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.tagline, this.detail});
  final String? tagline;

  /// A plain line under the tagline saying how the app works.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 52),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Multipost',
                style: TextStyle(
                  fontFamily: brandFace,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.1,
                  color: t.text,
                ),
              ),
            ),
          ],
        ),
        if (tagline != null) ...[
          const SizedBox(height: 12),
          Text(
            tagline!,
            style: TextStyle(fontSize: 19, height: 1.35, color: t.secondary),
          ),
        ],
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(detail!, style: TextStyle(fontSize: 16, color: t.text)),
        ],
      ],
    );
  }
}
