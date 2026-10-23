import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';
import 'package:subtitle_studio/widgets/dictionary_language_tab_colors.dart';

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  return ((l1 > l2 ? l1 : l2) + 0.05) /
      ((l1 < l2 ? l1 : l2) + 0.05);
}

void main() {
  for (final skin in StudioSkin.values) {
    for (final mode in StudioAppearance.values) {
      test('Olam selected language tab has readable $skin/$mode contrast', () {
        final theme = StudioThemeFactory.resolve(skin, mode);
        final colors = DictionaryLanguageTabColors.of(theme);
        expect(_contrast(colors.selectedBackground, colors.selectedForeground),
            greaterThanOrEqualTo(4.5));
        if (skin == StudioSkin.carbonZero &&
            mode != StudioAppearance.light) {
          expect(colors.neutralSelection, isTrue);
          expect(colors.selectedBackground,
              theme.colorScheme.surfaceContainerHigh);
          expect(colors.selectedForeground, theme.colorScheme.onSurface);
          expect(colors.selectedBackground.computeLuminance(), lessThan(0.1));
        } else {
          expect(colors.neutralSelection, isFalse);
          expect(colors.selectedBackground, theme.colorScheme.primary);
          expect(colors.selectedForeground, theme.colorScheme.onPrimary);
        }
      });
    }
  }
}
