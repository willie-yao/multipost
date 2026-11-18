import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

/// The user's caption as written. Shared captions read as plain ink; a
/// destination's own caption is ultramarine inside a ruled frame. Callers
/// always pair it with the words "Shared caption" or "Own caption".
class CaptionText extends StatelessWidget {
  const CaptionText(
    this.text, {
    super.key,
    this.own = false,
    this.maxLines,
    this.style,
  });

  final String text;
  final bool own;
  final int? maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final words = Text.rich(
      TextSpan(
        text: text,
        style: captionStyle(context)
            .merge(style)
            .copyWith(color: own ? t.own : t.text),
      ),
      softWrap: true,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
    if (!own) return words;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: t.own, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ownCaptionInset / 2 - 2,
          vertical: 6,
        ),
        child: words,
      ),
    );
  }
}

/// Horizontal space an own caption's frame takes (border plus padding).
const ownCaptionInset = 24.0;

/// Caption type: Atkinson Hyperlegible Next, sized for reading the post.
TextStyle captionStyle(BuildContext context) => const TextStyle(
  fontFamily: textFace,
  fontSize: 18,
  fontWeight: FontWeight.w600,
  height: 1.45,
);

/// Updates external text without resetting a live native IME or selection.
void syncCaptionText(TextEditingController controller, String text) {
  if (controller.text == text) return;
  final value = controller.value;
  final selection =
      value.selection.isValid && value.selection.end <= text.length
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  final composing =
      value.composing.isValid && value.composing.end <= text.length
      ? value.composing
      : TextRange.empty;
  controller.value = TextEditingValue(
    text: text,
    selection: selection,
    composing: composing,
  );
}

class CaptionEditor extends StatelessWidget {
  const CaptionEditor({
    super.key,
    required this.controller,
    required this.label,
    required this.own,
    required this.onChanged,
    this.readOnly = false,
  });
  final TextEditingController controller;
  final String label;
  final bool own;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    // Grow with the caption up to about 40% of the screen, then scroll inside,
    // so a long caption never pushes the destinations off at large text.
    final line = MediaQuery.textScalerOf(context).scale(20) * 1.45;
    final cap = (MediaQuery.sizeOf(context).height * 0.4 / line).floor();
    final maxLines = cap < 3 ? 3 : cap;
    return _field(context, maxLines);
  }

  Widget _field(BuildContext context, int maxLines) => TextField(
    controller: controller,
    readOnly: readOnly,
    minLines: 3,
    maxLines: maxLines,
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    style: TextStyle(
      fontFamily: textFace,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.45,
      color: own
          ? CaptionTokens.of(context).own
          : CaptionTokens.of(context).text,
    ),
    cursorColor: own
        ? CaptionTokens.of(context).own
        : CaptionTokens.of(context).text,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
    ),
    onChanged: onChanged,
  );
}
