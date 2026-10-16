import 'package:flutter/material.dart';

/// Selected-language tab colors in Olam's dictionary.
/// In Carbon Zero Dark/Classic (and achromatic community themes), primary
/// can be white. Use a dark neutral selected surface with readable text.
@immutable
class DictionaryLanguageTabColors {
  const DictionaryLanguageTabColors({
    required this.selectedBackground,
    required this.selectedForeground,
    required this.neutralSelection,
  });

  final Color selectedBackground;
  final Color selectedForeground;
  final bool neutralSelection;

  factory DictionaryLanguageTabColors.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final neutralDark = scheme.brightness == Brightness.dark &&
        HSLColor.fromColor(scheme.primary).saturation < 0.04;
    return DictionaryLanguageTabColors(
      selectedBackground:
          neutralDark ? scheme.surfaceContainerHigh : scheme.primary,
      selectedForeground:
          neutralDark ? scheme.onSurface : scheme.onPrimary,
      neutralSelection: neutralDark,
    );
  }
}
