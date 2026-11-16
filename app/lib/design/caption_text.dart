import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

class CaptionText extends StatelessWidget {
  const CaptionText(this.text, {super.key, this.own = false});

  final String text;
  final bool own;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: own ? CaptionTokens.own : CaptionTokens.text,
          backgroundColor: CaptionTokens.stage,
        ),
      ),
      softWrap: true,
    );
  }
}
