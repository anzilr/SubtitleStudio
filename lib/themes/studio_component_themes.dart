import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';

/// One component geometry and interaction contract for every appearance.
///
/// Skins provide semantic colors only: community JSON cannot change control
/// sizes, menu positioning, drag behavior, radii, or hit targets. Feature
/// widgets should use the Material theme defaults rather than local styleFrom
/// overrides, unless the action has a documented semantic exception.
abstract final class StudioComponentThemes {
  static ThemeData apply(ThemeData theme) {
    final tokens = theme.extension<StudioDesignTokens>() ??
        (theme.brightness == Brightness.dark
            ? StudioDesignTokens.dark
            : StudioDesignTokens.light);
    final text = theme.textTheme;

    const modalRadius = BorderRadius.vertical(
      top: Radius.circular(StudioRadius.sheet),
    );
    final popupShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadius.card),
      side: BorderSide(color: tokens.outline),
    );
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadius.sheet),
      side: BorderSide(color: tokens.outline),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadius.input),
    );
    const buttonSize = Size(
      StudioSizing.touchTarget,
      StudioSizing.touchTarget,
    );
    final buttonPadding = const EdgeInsets.symmetric(
      horizontal: StudioSpacing.md,
      vertical: StudioSpacing.xs,
    );

    return theme.copyWith(
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: modalRadius),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: tokens.mutedText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: dialogShape,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.lg,
          vertical: StudioSpacing.lg,
        ),
        titleTextStyle: text.titleLarge?.copyWith(
          color: tokens.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: tokens.onSurface,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.raisedSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: popupShape,
        textStyle: text.bodyMedium?.copyWith(color: tokens.onSurface),
        labelTextStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(color: tokens.onSurface),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.raisedSurface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(popupShape),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: StudioSpacing.xs),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium?.copyWith(color: tokens.onSurface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.raisedSurface),
          shape: WidgetStatePropertyAll(popupShape),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: tokens.fieldSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: StudioSpacing.sm,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StudioRadius.input),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StudioRadius.input),
            borderSide: BorderSide(color: tokens.fieldBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StudioRadius.input),
            borderSide: BorderSide(color: tokens.focusBorder, width: 2),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: tokens.primaryAction,
        inactiveTrackColor: tokens.outline,
        disabledActiveTrackColor: tokens.outline,
        disabledInactiveTrackColor: tokens.outline.withValues(alpha: 0.6),
        thumbColor: tokens.primaryAction,
        disabledThumbColor: tokens.disabledText,
        overlayColor: tokens.primaryAction.withValues(alpha: 0.14),
        valueIndicatorColor: tokens.raisedSurface,
        valueIndicatorTextStyle: text.labelMedium?.copyWith(
          color: tokens.onSurface,
        ),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primaryAction,
          foregroundColor: tokens.onPrimaryAction,
          disabledBackgroundColor: tokens.outline,
          disabledForegroundColor: tokens.disabledText,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.raisedSurface,
          foregroundColor: tokens.onSurface,
          disabledBackgroundColor: tokens.outline,
          disabledForegroundColor: tokens.disabledText,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          elevation: 0,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primaryAction,
          disabledForegroundColor: tokens.disabledText,
          side: BorderSide(color: tokens.fieldBorder),
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primaryAction,
          disabledForegroundColor: tokens.disabledText,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.onSurface,
          disabledForegroundColor: tokens.disabledText,
          minimumSize: buttonSize,
          shape: buttonShape,
          iconSize: StudioSizing.icon,
        ),
      ),
      // Segmented buttons share the same geometry as other controls; mode
      // buttons are no longer given a bespoke appearance per screen.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(buttonShape),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return tokens.disabledText;
            }
            if (states.contains(WidgetState.selected)) {
              return tokens.onPrimaryAction;
            }
            return tokens.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.primaryAction;
            }
            return tokens.surface;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: tokens.fieldBorder),
          ),
        ),
      ),
      // Preserve Material semantics for error, success, and warning actions.
      // Destructive controls must still opt into scheme.error/onError roles.
      // Color accents in subtitle content are data, not UI component styling.
    );
  }
}
