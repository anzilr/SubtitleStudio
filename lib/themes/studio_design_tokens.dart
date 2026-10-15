import 'package:flutter/material.dart';

/// SubtitleStudio's editing-oriented visual language.
///
/// Use semantic roles instead of hard-coded colors in feature widgets. The
/// legacy Material ColorScheme stays unchanged until each screen is migrated;
/// this ThemeExtension allows safe, opt-in adoption and theme interpolation.
@immutable
class StudioDesignTokens extends ThemeExtension<StudioDesignTokens> {
  const StudioDesignTokens({
    required this.canvas,
    required this.surface,
    required this.raisedSurface,
    required this.fieldSurface,
    required this.onSurface,
    required this.mutedText,
    required this.outline,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.editingAccent,
    required this.onEditingAccent,
    required this.caution,
    required this.onCaution,
    required this.dangerText,
    required this.historyAlternate,
  });

  final Color canvas;
  final Color surface;
  final Color raisedSurface;
  final Color fieldSurface;
  final Color onSurface;
  final Color mutedText;
  final Color outline;
  final Color primaryAction;
  final Color onPrimaryAction;
  final Color editingAccent;
  final Color onEditingAccent;
  final Color caution;
  final Color onCaution;
  final Color dangerText;
  final Color historyAlternate;

  static const StudioDesignTokens light = StudioDesignTokens(
    canvas: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    raisedSurface: Color(0xFFFFFFFF),
    fieldSurface: Color(0xFFF0F3FA),
    onSurface: Color(0xFF17223B),
    mutedText: Color(0xFF66728D),
    outline: Color(0xFFD7DEEC),
    primaryAction: Color(0xFF5268D9),
    onPrimaryAction: Color(0xFFFFFFFF),
    editingAccent: Color(0xFF14796F),
    onEditingAccent: Color(0xFFFFFFFF),
    caution: Color(0xFFD99B37),
    onCaution: Color(0xFF111A2C),
    dangerText: Color(0xFFA33A39),
    historyAlternate: Color(0xFF188579),
  );

  static const StudioDesignTokens dark = StudioDesignTokens(
    canvas: Color(0xFF111A2C),
    surface: Color(0xFF19243A),
    raisedSurface: Color(0xFF22314A),
    fieldSurface: Color(0xFF25344C),
    onSurface: Color(0xFFEEF2FA),
    mutedText: Color(0xFFB5C0D8),
    outline: Color(0xFF46546C),
    primaryAction: Color(0xFFA9B6FF),
    onPrimaryAction: Color(0xFF111A2C),
    editingAccent: Color(0xFF62DBCA),
    onEditingAccent: Color(0xFF111A2C),
    caution: Color(0xFFF2B85B),
    onCaution: Color(0xFF111A2C),
    dangerText: Color(0xFFFF8A9A),
    historyAlternate: Color(0xFF62DBCA),
  );

  /// The existing Classic theme is a dark legacy preference. New Studio
  /// components use the same accessible dark tokens without rewriting it.
  static const StudioDesignTokens classic = dark;

  static StudioDesignTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StudioDesignTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  StudioDesignTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? raisedSurface,
    Color? fieldSurface,
    Color? onSurface,
    Color? mutedText,
    Color? outline,
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? editingAccent,
    Color? onEditingAccent,
    Color? caution,
    Color? onCaution,
    Color? dangerText,
    Color? historyAlternate,
  }) {
    return StudioDesignTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      fieldSurface: fieldSurface ?? this.fieldSurface,
      onSurface: onSurface ?? this.onSurface,
      mutedText: mutedText ?? this.mutedText,
      outline: outline ?? this.outline,
      primaryAction: primaryAction ?? this.primaryAction,
      onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
      editingAccent: editingAccent ?? this.editingAccent,
      onEditingAccent: onEditingAccent ?? this.onEditingAccent,
      caution: caution ?? this.caution,
      onCaution: onCaution ?? this.onCaution,
      dangerText: dangerText ?? this.dangerText,
      historyAlternate: historyAlternate ?? this.historyAlternate,
    );
  }

  @override
  StudioDesignTokens lerp(
    covariant ThemeExtension<StudioDesignTokens>? other,
    double t,
  ) {
    if (other is! StudioDesignTokens) return this;
    return StudioDesignTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      fieldSurface: Color.lerp(fieldSurface, other.fieldSurface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      onPrimaryAction: Color.lerp(onPrimaryAction, other.onPrimaryAction, t)!,
      editingAccent: Color.lerp(editingAccent, other.editingAccent, t)!,
      onEditingAccent: Color.lerp(onEditingAccent, other.onEditingAccent, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      onCaution: Color.lerp(onCaution, other.onCaution, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      historyAlternate: Color.lerp(historyAlternate, other.historyAlternate, t)!,
    );
  }
}

/// Shared layout rhythm for mobile, tablet and eventual desktop components.
abstract final class StudioSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class StudioRadius {
  static const double input = 8;
  static const double card = 12;
  static const double sheet = 16;
}

abstract final class StudioSizing {
  static const double touchTarget = 48;
  static const double icon = 20;
}
