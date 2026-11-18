import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'caption_tokens.dart';

ThemeData captionTheme([Brightness brightness = Brightness.light]) {
  final t = brightness == Brightness.dark
      ? CaptionTokens.dark
      : CaptionTokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.action,
    onPrimary: t.onAction,
    primaryContainer: t.raised2,
    onPrimaryContainer: t.text,
    secondary: t.text,
    onSecondary: t.onAction,
    secondaryContainer: t.raised2,
    onSecondaryContainer: t.text,
    // Ultramarine is reserved for labelled own captions, never a default role.
    tertiary: t.text,
    onTertiary: t.onAction,
    tertiaryContainer: t.raised2,
    onTertiaryContainer: t.text,
    error: t.error,
    onError: t.onAction,
    errorContainer: t.raised,
    onErrorContainer: t.error,
    surface: t.ground,
    onSurface: t.text,
    onSurfaceVariant: t.secondary,
    surfaceDim: t.ground,
    surfaceBright: t.sheet,
    surfaceContainerLowest: t.sheet,
    surfaceContainerLow: t.sheet,
    surfaceContainer: t.sheet,
    surfaceContainerHigh: t.sheet,
    surfaceContainerHighest: t.raised,
    outline: t.boundary,
    outlineVariant: t.hairline,
    inverseSurface: t.text,
    onInverseSurface: t.ground,
    inversePrimary: t.onAction,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: textFace,
  );
  const buttonText = TextStyle(
    fontFamily: textFace,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return base.copyWith(
    scaffoldBackgroundColor: t.ground,
    extensions: [t],
    textTheme: base.textTheme
        .copyWith(
          titleLarge: const TextStyle(
            fontFamily: brandFace,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            height: 1.25,
          ),
          titleMedium: const TextStyle(
            fontFamily: brandFace,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          titleSmall: const TextStyle(
            fontFamily: brandFace,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 16, height: 1.45),
          bodySmall: const TextStyle(fontSize: 14, height: 1.4),
          labelLarge: buttonText,
          labelMedium: const TextStyle(fontSize: 14),
          labelSmall: const TextStyle(fontSize: 14),
        )
        .apply(bodyColor: t.text, displayColor: t.text),
    dividerTheme: DividerThemeData(color: t.hairline, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.action,
        foregroundColor: t.onAction,
        disabledBackgroundColor: t.raised2,
        disabledForegroundColor: t.secondary,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: buttonText,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: t.text,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: buttonText.copyWith(fontSize: 16),
            side: BorderSide(color: t.text, width: 2),
            shape: shape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? t.boundary
                    : t.text,
                width: 2,
              ),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.text,
        minimumSize: const Size(48, 48),
        textStyle: buttonText.copyWith(fontSize: 16),
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: t.text,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? t.action
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(t.onAction),
      side: BorderSide(color: t.text, width: 2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.onAction : t.boundary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.action : t.raised,
      ),
      trackOutlineColor: WidgetStatePropertyAll(t.boundary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: t.sheet,
      selectedColor: t.action,
      checkmarkColor: t.onAction,
      side: BorderSide(color: t.boundary),
      // RawChip reads only labelStyle; its colour must follow selection.
      labelStyle: TextStyle(
        fontFamily: textFace,
        fontSize: 16,
        color: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.onAction : t.text,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.text,
      linearTrackColor: t.raised,
      circularTrackColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      textColor: t.text,
      iconColor: t.text,
      subtitleTextStyle: TextStyle(
        fontFamily: textFace,
        fontSize: 15,
        height: 1.4,
        color: t.secondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(
        fontFamily: brandFace,
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: t.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: textFace,
        fontSize: 16,
        height: 1.45,
        color: t.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: TextStyle(
        fontFamily: textFace,
        fontSize: 16,
        color: t.ground,
      ),
      actionTextColor: t.ground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.text,
      selectionColor: t.text.withValues(alpha: 0.22),
      selectionHandleColor: t.text,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: t.sheet,
      labelStyle: TextStyle(fontFamily: textFace, color: t.secondary),
      floatingLabelStyle: TextStyle(fontFamily: textFace, color: t.secondary),
      border: UnderlineInputBorder(borderSide: BorderSide(color: t.boundary)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.boundary),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: t.text, width: 2),
      ),
    ),
  );
}

SystemUiOverlayStyle captionOverlay(BuildContext context) {
  final t = CaptionTokens.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: t.ground,
    statusBarIconBrightness: icons,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: t.ground,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarDividerColor: t.hairline,
    // Edge-to-edge (Android 15+) ignores the colours above and adds a scrim
    // taken from the launch theme, which goes stale when the system switches
    // light/dark while the app is open. Let the app's own ground show instead.
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}
