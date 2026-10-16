import 'package:flutter/material.dart';

import 'studio_palette.dart';
import 'studio_skin.dart';

/// The same import-time checks apply to imported skins and UI-created skins.
/// Errors reject the entire package before it can become a current theme.
abstract final class StudioSkinValidator {
  static double contrastRatio(Color first, Color second) {
    final a = first.computeLuminance();
    final b = second.computeLuminance();
    return ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
  }

  static void validate({
    required StudioSkinId id,
    required Map<StudioAppearance, StudioPalette> palettes,
    String? author,
    String? description,
  }) {
    if (id.isBuiltIn) {
      throw const FormatException('Imported skins may not replace built-ins');
    }
    if (author != null && author!.length > 100) {
      throw const FormatException('Skin author is too long');
    }
    if (description != null && description!.length > 500) {
      throw const FormatException('Skin description is too long');
    }
    for (final mode in StudioAppearance.values) {
      final palette = palettes[mode]!;
      _validatePalette(mode, palette);
    }
  }

  static void _validatePalette(
    StudioAppearance mode,
    StudioPalette palette,
  ) {
    final colors = <String, Color>{
      'canvas': palette.canvas,
      'surface': palette.surface,
      'raisedSurface': palette.raisedSurface,
      'fieldSurface': palette.fieldSurface,
      'onSurface': palette.onSurface,
      'mutedText': palette.mutedText,
      'outline': palette.outline,
      'fieldBorder': palette.fieldBorder,
      'accent': palette.accent,
      'onAccent': palette.onAccent,
      'appBar': palette.appBar,
      'onAppBar': palette.onAppBar,
    };
    for (final color in colors.entries) {
      if (color.value.a < 1.0) {
        throw FormatException(
          '${mode.label}: ${color.key} must be an opaque color',
        );
      }
    }

    void readable(
      String role,
      Color foreground,
      Color background, {
      double ratio = 4.5,
    }) {
      if (contrastRatio(foreground, background) < ratio) {
        throw FormatException(
          '${mode.label}: $role does not meet $ratio:1 contrast',
        );
      }
    }

    readable('surface text', palette.onSurface, palette.surface);
    readable('canvas text', palette.onSurface, palette.canvas);
    readable('field text', palette.onSurface, palette.fieldSurface);
    readable('secondary field text', palette.mutedText, palette.fieldSurface);
    readable('button text', palette.onAccent, palette.accent);
    readable('app bar text', palette.onAppBar, palette.appBar);
    readable('error text', palette.danger, palette.surface);
    readable('warning text', palette.caution, palette.surface);
    readable('input outline', palette.fieldBorder, palette.fieldSurface,
        ratio: 3);
  }
}
