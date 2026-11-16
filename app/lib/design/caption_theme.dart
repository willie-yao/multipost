import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

ThemeData captionTheme() {
  const scheme = ColorScheme.dark(
    primary: CaptionTokens.text,
    onPrimary: CaptionTokens.onAction,
    primaryContainer: CaptionTokens.raised2,
    onPrimaryContainer: CaptionTokens.text,
    secondary: CaptionTokens.own,
    onSecondary: CaptionTokens.onAction,
    secondaryContainer: CaptionTokens.raised2,
    onSecondaryContainer: CaptionTokens.own,
    tertiary: CaptionTokens.warning,
    onTertiary: CaptionTokens.onAction,
    tertiaryContainer: CaptionTokens.raised2,
    onTertiaryContainer: CaptionTokens.warning,
    error: CaptionTokens.error,
    onError: CaptionTokens.onAction,
    errorContainer: CaptionTokens.raised2,
    onErrorContainer: CaptionTokens.error,
    surface: CaptionTokens.ground,
    onSurface: CaptionTokens.text,
    onSurfaceVariant: CaptionTokens.secondary,
    surfaceDim: CaptionTokens.ground,
    surfaceBright: CaptionTokens.raised2,
    surfaceContainerLowest: CaptionTokens.stage,
    surfaceContainerLow: CaptionTokens.ground,
    surfaceContainer: CaptionTokens.raised,
    surfaceContainerHigh: CaptionTokens.raised2,
    surfaceContainerHighest: CaptionTokens.raised2,
    outline: CaptionTokens.boundary,
    outlineVariant: CaptionTokens.hairline,
    inverseSurface: CaptionTokens.text,
    onInverseSurface: CaptionTokens.onAction,
    inversePrimary: CaptionTokens.onAction,
    shadow: CaptionTokens.stage,
    scrim: CaptionTokens.stage,
    surfaceTint: CaptionTokens.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Atkinson Hyperlegible Next',
  );
  const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  return base.copyWith(
    scaffoldBackgroundColor: CaptionTokens.ground,
    textTheme: base.textTheme
        .copyWith(
          titleLarge: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16),
          bodyMedium: const TextStyle(fontSize: 16),
          bodySmall: const TextStyle(fontSize: 14),
          labelLarge: buttonText,
          labelMedium: const TextStyle(fontSize: 14),
          labelSmall: const TextStyle(fontSize: 14),
        )
        .apply(
          fontFamily: 'Atkinson Hyperlegible Next',
          bodyColor: CaptionTokens.text,
          displayColor: CaptionTokens.text,
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CaptionTokens.text,
        foregroundColor: CaptionTokens.onAction,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CaptionTokens.text,
        minimumSize: const Size(48, 48),
        textStyle: buttonText,
        side: const BorderSide(color: CaptionTokens.boundary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CaptionTokens.text,
        minimumSize: const Size(48, 48),
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: CaptionTokens.text,
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: CaptionTokens.raised,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: CaptionTokens.boundary),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: CaptionTokens.text, width: 2),
      ),
    ),
  );
}
