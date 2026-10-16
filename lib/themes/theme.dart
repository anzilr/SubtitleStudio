import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// A restrained Material theme for the whole application. Feature widgets
/// should use ColorScheme and StudioDesignTokens instead of adding unrelated
/// hard-coded accent colors. AppBar chrome stays dark for compatibility with
/// older editor buttons that still use white icons/text.
class AppThemes {
  static const Color _brand = Color(0xFF5268D9);
  static const Color _navy = Color(0xFF1D2D4F);
  static const Color _teal = Color(0xFF14796F);
  static const Color _danger = Color(0xFFA33A39);

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: _brand,
    onPrimary: Colors.white,
    secondary: _teal,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF17223B),
    error: _danger,
    onError: Colors.white,
    outline: Color(0xFFD7DEEC),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFAFBFD),
    surfaceContainer: Color(0xFFF5F7FB),
    surfaceContainerHigh: Color(0xFFEEF2F9),
    surfaceContainerHighest: Color(0xFFE5EAF5),
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: _brand,
    onPrimary: Colors.white,
    secondary: Color(0xFF62DBCA),
    onSecondary: Color(0xFF111A2C),
    surface: Color(0xFF19243A),
    onSurface: Color(0xFFEEF2FA),
    error: Color(0xFFFF8A9A),
    onError: Color(0xFF111A2C),
    outline: Color(0xFF46546C),
    surfaceContainerLowest: Color(0xFF111A2C),
    surfaceContainerLow: Color(0xFF152036),
    surfaceContainer: Color(0xFF1C2940),
    surfaceContainerHigh: Color(0xFF22314A),
    surfaceContainerHighest: Color(0xFF2B3A53),
  );

  static final TextTheme _baseType = Typography.material2021().black;

  static ThemeData _build({
    required ColorScheme scheme,
    required StudioDesignTokens tokens,
    required Color canvas,
    required Color appBar,
  }) {
    final textTheme = _baseType.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: scheme.surface,
      dividerColor: scheme.outline,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.brightness == Brightness.light
            ? _navy
            : const Color(0xFF2B3A53),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: TextStyle(color: scheme.primary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }

  // Keep the light canvas pure white; elevated components are distinguished
  // through borders rather than a broad grey overlay behind the editor.
  static final ThemeData lightTheme = _build(
    scheme: _lightScheme,
    tokens: StudioDesignTokens.light,
    canvas: Colors.white,
    appBar: _navy,
  );

  static final ThemeData darkTheme = _build(
    scheme: _darkScheme,
    tokens: StudioDesignTokens.dark,
    canvas: const Color(0xFF111A2C),
    appBar: const Color(0xFF15233C),
  );

  // Saved "classic" preference remains supported as high-contrast dark,
  // using the same brand accents instead of introducing a third palette.
  static final ThemeData classicTheme = _build(
    scheme: _darkScheme,
    tokens: StudioDesignTokens.classic,
    canvas: Colors.black,
    appBar: Colors.black,
  );
}
