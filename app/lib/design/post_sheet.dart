import 'package:material_ui/material_ui.dart';

import 'brand_mark.dart';
import 'caption_tokens.dart';

/// The post sheet: one plain raised surface that holds the post itself, or
/// the single row that needs the person's action. Not a general card.
class PostSheet extends StatelessWidget {
  const PostSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.sheet,
        border: Border.all(color: t.hairline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// "Shared caption" (with a ditto sign) or "Own caption" (ultramarine).
/// The words always carry the meaning; colour and sign only repeat it.
class CaptionSourceLabel extends StatelessWidget {
  const CaptionSourceLabel({super.key, required this.own, this.text});
  final bool own;

  /// Overrides the default words, e.g. "Own caption · reviewed version".
  final String? text;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final words = text ?? (own ? 'Own caption' : 'Shared caption');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (own)
          Icon(Icons.edit_outlined, size: 16, color: t.own)
        else
          const DittoGlyph(size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            words,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: own ? t.own : t.secondary,
              fontWeight: own ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Shared media" (ditto sign) or "Own media · N" (ink). Media inheritance is
/// independent of the caption's, so each row says both. Ultramarine stays
/// reserved for the caption.
class MediaSourceLabel extends StatelessWidget {
  const MediaSourceLabel({super.key, this.ownCount});

  /// Null when the destination uses the shared media.
  final int? ownCount;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final own = ownCount != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (own)
          Icon(Icons.photo_library_outlined, size: 16, color: t.text)
        else
          const DittoGlyph(size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            own ? 'Own media · $ownCount' : 'Shared media',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: own ? t.text : t.secondary,
              fontWeight: own ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
