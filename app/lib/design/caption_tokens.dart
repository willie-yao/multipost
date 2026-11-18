import 'package:material_ui/material_ui.dart';

/// Multipost colour roles for the Impression direction, light and dark.
///
/// Material roles carry ordinary chrome; these name the jobs Material has no
/// role for. [own] marks a destination's own caption and nothing else.
@immutable
class CaptionTokens extends ThemeExtension<CaptionTokens> {
  const CaptionTokens({
    required this.ground,
    required this.sheet,
    required this.raised,
    required this.raised2,
    required this.text,
    required this.secondary,
    required this.own,
    required this.hairline,
    required this.boundary,
    required this.success,
    required this.onSuccess,
    required this.error,
    required this.warning,
    required this.action,
    required this.onAction,
  });

  /// Card-stock ground behind every screen.
  final Color ground;

  /// The post sheet and the one raised row that needs action.
  final Color sheet;

  /// Tonal fills: fields, notices, placeholders.
  final Color raised, raised2;
  final Color text, secondary;

  /// A destination's own caption. Always paired with the words "Own caption".
  final Color own;
  final Color hairline, boundary;
  final Color success, onSuccess, error, warning;

  /// The single filled action per screen.
  final Color action, onAction;

  static const light = CaptionTokens(
    ground: Color(0xFFF2F3F0),
    sheet: Color(0xFFFFFFFF),
    raised: Color(0xFFE6E8E4),
    raised2: Color(0xFFD9DCD7),
    text: Color(0xFF16171A),
    secondary: Color(0xFF4B5058),
    own: Color(0xFF2B3BC9),
    hairline: Color(0xFFD9DCDF),
    boundary: Color(0xFF7A7F87),
    success: Color(0xFF1C6B3A),
    onSuccess: Color(0xFFFFFFFF),
    error: Color(0xFFB3261E),
    warning: Color(0xFF7A5300),
    action: Color(0xFF16171A),
    onAction: Color(0xFFFFFFFF),
  );

  static const dark = CaptionTokens(
    ground: Color(0xFF121315),
    sheet: Color(0xFF1C1E21),
    raised: Color(0xFF26292D),
    raised2: Color(0xFF32363B),
    text: Color(0xFFF1F2EE),
    secondary: Color(0xFFB4B9BF),
    own: Color(0xFFA9B4FF),
    hairline: Color(0xFF2E3135),
    boundary: Color(0xFF7D848C),
    success: Color(0xFF86D3A0),
    onSuccess: Color(0xFF0B1A10),
    error: Color(0xFFFF9C94),
    warning: Color(0xFFE9C46A),
    action: Color(0xFFF1F2EE),
    onAction: Color(0xFF16171A),
  );

  static CaptionTokens of(BuildContext context) =>
      Theme.of(context).extension<CaptionTokens>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  CaptionTokens copyWith() => this;

  @override
  CaptionTokens lerp(CaptionTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return CaptionTokens(
      ground: c(ground, other.ground),
      sheet: c(sheet, other.sheet),
      raised: c(raised, other.raised),
      raised2: c(raised2, other.raised2),
      text: c(text, other.text),
      secondary: c(secondary, other.secondary),
      own: c(own, other.own),
      hairline: c(hairline, other.hairline),
      boundary: c(boundary, other.boundary),
      success: c(success, other.success),
      onSuccess: c(onSuccess, other.onSuccess),
      error: c(error, other.error),
      warning: c(warning, other.warning),
      action: c(action, other.action),
      onAction: c(onAction, other.onAction),
    );
  }
}

/// Rubik is the voice face: names, titles and state marks.
const brandFace = 'Rubik';

/// Atkinson Hyperlegible Next carries the user's words and every control.
const textFace = 'Atkinson Hyperlegible Next';
