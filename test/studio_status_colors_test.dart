import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/themes/studio_palette.dart';
import 'package:subtitle_studio/themes/studio_skin.dart';
import 'package:subtitle_studio/themes/studio_status_colors.dart';
import 'package:subtitle_studio/themes/studio_theme_factory.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
}

void main() {
  test('all twelve appearances use one high-contrast safety color contract', () {
    for (final mode in StudioAppearance.values) {
      final reference = StudioPalette.resolve(StudioSkin.carbonZero, mode);
      for (final skin in StudioSkin.values) {
        final palette = StudioPalette.resolve(skin, mode);
        final scheme = StudioThemeFactory.resolve(skin, mode).colorScheme;
        expect(palette.danger, reference.danger);
        expect(palette.caution, reference.caution);
        expect(palette.onDanger, reference.onDanger);
        expect(palette.onCaution, reference.onCaution);
        expect(scheme.error, palette.danger);
        expect(scheme.onError, palette.onDanger);
        expect(contrast(scheme.error, scheme.onError), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.caution, palette.surface),
            greaterThanOrEqualTo(4.5));
        expect(contrast(palette.danger, palette.surface),
            greaterThanOrEqualTo(4.5));
      }
    }
    expect(StudioStatusColors.dangerLight, isNot(StudioStatusColors.warningLight));
    expect(StudioStatusColors.dangerDark, isNot(StudioStatusColors.warningDark));
  });
}
