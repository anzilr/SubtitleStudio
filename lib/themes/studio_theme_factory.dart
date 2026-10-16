import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';
import 'studio_palette.dart';
import 'studio_skin_catalog.dart';
import 'studio_skin.dart';

/// Builds one shared Material/Studio design system from the selected colors.
///
/// SKIN-1 deliberately does NOT install this factory in MainApp. The current
/// Editor still contains hard-coded white-on-primary editing fields; routing
/// production through new palettes before SKIN-4 would harm readability.
abstract final class StudioThemeFactory {
  static ThemeData resolve(
    StudioSkin skin,
    StudioAppearance appearance, {
    String? fontFamily,
  }) => fromPalette(
        StudioPalette.resolve(skin, appearance),
        fontFamily: fontFamily,
      );

  /// Built-in and community skins share precisely the same renderer.
  /// Neither an Isar record nor a downloaded file is executable theme code.
  static ThemeData fromDefinition(
    StudioSkinDefinition definition,
    StudioAppearance appearance, {
    String? fontFamily,
  }) =>
      fromPalette(
        definition.paletteFor(appearance),
        fontFamily: fontFamily,
      );

  /// Pure rendering boundary used by all future skin sources.
  static ThemeData fromPalette(
    StudioPalette palette, {
    String? fontFamily,
  }) {
    final tokens = palette.tokens;
    final scheme = (palette.isDark
            ? ColorScheme.dark(
                primary: palette.accent,
                onPrimary: palette.onAccent,
                secondary: palette.accent,
                onSecondary: palette.onAccent,
                surface: palette.surface,
                onSurface: palette.onSurface,
                error: palette.danger,
                onError: palette.onDanger,
                outline: palette.outline,
              )
            : ColorScheme.light(
                primary: palette.accent,
                onPrimary: palette.onAccent,
                secondary: palette.accent,
                onSecondary: palette.onAccent,
                surface: palette.surface,
                onSurface: palette.onSurface,
                error: palette.danger,
                onError: palette.onDanger,
                outline: palette.outline,
              ))
        .copyWith(
          primaryContainer: palette.fieldSurface,
          onPrimaryContainer: palette.onSurface,
          secondaryContainer: palette.raisedSurface,
          onSecondaryContainer: palette.onSurface,
          tertiary: palette.caution,
          onTertiary: palette.onCaution,
          surfaceContainerLowest: palette.canvas,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.fieldSurface,
          surfaceContainerHigh: palette.raisedSurface,
          surfaceContainerHighest: palette.raisedSurface,
          onSurfaceVariant: palette.mutedText,
          outlineVariant: palette.outline,
        );

    final typography = Typography.material2021();
    final textTheme =
        (palette.isDark ? typography.white : typography.black).apply(
      bodyColor: palette.onSurface,
      displayColor: palette.onSurface,
      fontFamily: fontFamily,
    );
    const inputRadius = StudioRadius.input;
    final inputShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: BorderSide(color: palette.fieldBorder),
    );
    final focusedShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: BorderSide(color: palette.accent, width: 2),
    );
    final errorShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: BorderSide(color: palette.danger),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      cardColor: palette.surface,
      dividerColor: palette.outline,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.onSurface),
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBar,
        foregroundColor: palette.onAppBar,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.onAppBar,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: palette.onAppBar),
        actionsIconTheme: IconThemeData(color: palette.onAppBar),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioRadius.card),
          side: BorderSide(color: palette.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.fieldSurface,
        labelStyle: TextStyle(color: palette.mutedText),
        floatingLabelStyle: TextStyle(color: palette.accent),
        border: inputShape,
        enabledBorder: inputShape,
        focusedBorder: focusedShape,
        errorBorder: errorShape,
        focusedErrorBorder: errorShape.copyWith(
          borderSide: BorderSide(color: palette.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.sm,
          vertical: StudioSpacing.sm,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.caret,
        selectionColor: tokens.selection,
        selectionHandleColor: palette.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize:
              const Size(StudioSizing.touchTarget, StudioSizing.touchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioRadius.input),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.raisedSurface,
        contentTextStyle: TextStyle(color: palette.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioRadius.sheet),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
      ),
    );
  }
}
