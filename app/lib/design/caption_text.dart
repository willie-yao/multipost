import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

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
    return Text.rich(
      TextSpan(
        text: text,
        style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
          color: own ? CaptionTokens.own : CaptionTokens.text,
          backgroundColor: CaptionTokens.stage,
        ),
      ),
      softWrap: true,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

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
  Widget build(BuildContext context) => TextField(
    controller: controller,
    readOnly: readOnly,
    minLines: 3,
    maxLines: null,
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    style: TextStyle(
      fontFamily: 'Atkinson Hyperlegible Next',
      fontSize: 21,
      fontWeight: FontWeight.w600,
      height: 34 / 21,
      color: own ? CaptionTokens.own : CaptionTokens.text,
      backgroundColor: CaptionTokens.stage,
    ),
    cursorColor: CaptionTokens.own,
    decoration: InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      filled: true,
      fillColor: CaptionTokens.raised,
      contentPadding: const EdgeInsets.all(16),
    ),
    onChanged: onChanged,
  );
}
