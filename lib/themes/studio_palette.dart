import 'package:flutter/material.dart';

import 'studio_design_tokens.dart';
import 'studio_skin.dart';

/// Data-only theme colors. Widgets must use the resolved semantic tokens,
/// never reach into these named palettes for ad-hoc decorative colors.
@immutable
class StudioPalette {
  const StudioPalette({
    required this.appearance,
    required this.canvas,
    required this.surface,
    required this.raisedSurface,
    required this.fieldSurface,
    required this.onSurface,
    required this.mutedText,
    required this.outline,
    required this.fieldBorder,
    required this.accent,
    required this.onAccent,
    required this.appBar,
    required this.onAppBar,
  });

  final StudioAppearance appearance;
  final Color canvas;
  final Color surface;
  final Color raisedSurface;
  final Color fieldSurface;
  final Color onSurface;
  final Color mutedText;
  final Color outline;
  final Color fieldBorder;
  final Color accent;
  final Color onAccent;
  final Color appBar;
  final Color onAppBar;

  bool get isDark => appearance != StudioAppearance.light;
  Brightness get brightness => isDark ? Brightness.dark : Brightness.light;

  // Functional colors are shared across skins, not decorative palette accents.
  Color get caution =>
      isDark ? const Color(0xFFF2B85B) : const Color(0xFF93601E);
  Color get onCaution =>
      isDark ? const Color(0xFF111A2C) : Colors.white;
  Color get danger =>
      isDark ? const Color(0xFFFF8A9A) : const Color(0xFFA33A39);
  Color get onDanger =>
      isDark ? const Color(0xFF111A2C) : Colors.white;
  Color get success => accent;
  Color get onSuccess => onAccent;

  StudioDesignTokens get tokens => StudioDesignTokens(
        canvas: canvas,
        surface: surface,
        raisedSurface: raisedSurface,
        fieldSurface: fieldSurface,
        onSurface: onSurface,
        mutedText: mutedText,
        outline: outline,
        fieldBorder: fieldBorder,
        focusBorder: accent,
        selection: accent.withValues(alpha: 0.26),
        caret: accent,
        disabledText: mutedText,
        primaryAction: accent,
        onPrimaryAction: onAccent,
        editingAccent: accent,
        onEditingAccent: onAccent,
        caution: caution,
        onCaution: onCaution,
        dangerText: danger,
        historyAlternate: accent,
      );

  static StudioPalette resolve(
    StudioSkin skin,
    StudioAppearance appearance,
  ) {
    return switch ((skin, appearance)) {
      (StudioSkin.carbonJade, StudioAppearance.light) => _jadeLight,
      (StudioSkin.carbonJade, StudioAppearance.dark) => _jadeDark,
      (StudioSkin.carbonJade, StudioAppearance.classic) => _jadeClassic,
      (StudioSkin.copperCinema, StudioAppearance.light) => _copperLight,
      (StudioSkin.copperCinema, StudioAppearance.dark) => _copperDark,
      (StudioSkin.copperCinema, StudioAppearance.classic) => _copperClassic,
      (StudioSkin.asterViolet, StudioAppearance.light) => _asterLight,
      (StudioSkin.asterViolet, StudioAppearance.dark) => _asterDark,
      (StudioSkin.asterViolet, StudioAppearance.classic) => _asterClassic,
    };
  }

  static const _jadeLight = StudioPalette(
    appearance: StudioAppearance.light,
    canvas: Color(0xFFFFFFFF),
    surface: Color(0xFFF7FBF9),
    raisedSurface: Color(0xFFFFFFFF),
    fieldSurface: Color(0xFFF0F8F4),
    onSurface: Color(0xFF192B25),
    mutedText: Color(0xFF526960),
    outline: Color(0xFFB8D0C6),
    fieldBorder: Color(0xFF698A7D),
    accent: Color(0xFF0A7860),
    onAccent: Colors.white,
    appBar: Color(0xFF153D35),
    onAppBar: Colors.white,
  );

  static const _jadeDark = StudioPalette(
    appearance: StudioAppearance.dark,
    canvas: Color(0xFF0E1517),
    surface: Color(0xFF182427),
    raisedSurface: Color(0xFF263639),
    fieldSurface: Color(0xFF213135),
    onSurface: Color(0xFFF2F8F5),
    mutedText: Color(0xFFB4C8C2),
    outline: Color(0xFF42575A),
    fieldBorder: Color(0xFF7A8E8B),
    accent: Color(0xFF55E0BC),
    onAccent: Color(0xFF07281E),
    appBar: Color(0xFF182427),
    onAppBar: Color(0xFFF2F8F5),
  );

  static const _jadeClassic = StudioPalette(
    appearance: StudioAppearance.classic,
    canvas: Color(0xFF050909),
    surface: Color(0xFF131B1A),
    raisedSurface: Color(0xFF25332F),
    fieldSurface: Color(0xFF1B2926),
    onSurface: Color(0xFFF5F8F3),
    mutedText: Color(0xFFB6C8C1),
    outline: Color(0xFF455751),
    fieldBorder: Color(0xFF798E85),
    accent: Color(0xFF56DEB6),
    onAccent: Color(0xFF07281E),
    appBar: Color(0xFF131B1A),
    onAppBar: Color(0xFFF5F8F3),
  );

  static const _copperLight = StudioPalette(
    appearance: StudioAppearance.light,
    canvas: Color(0xFFFFFEFC),
    surface: Color(0xFFFFFFFF),
    raisedSurface: Color(0xFFFFFFFF),
    fieldSurface: Color(0xFFFFF8EF),
    onSurface: Color(0xFF2F2521),
    mutedText: Color(0xFF69584D),
    outline: Color(0xFFDBC7B4),
    fieldBorder: Color(0xFFA08570),
    accent: Color(0xFF93601E),
    onAccent: Colors.white,
    appBar: Color(0xFF3B2921),
    onAppBar: Colors.white,
  );

  static const _copperDark = StudioPalette(
    appearance: StudioAppearance.dark,
    canvas: Color(0xFF151414),
    surface: Color(0xFF242020),
    raisedSurface: Color(0xFF3B322F),
    fieldSurface: Color(0xFF302826),
    onSurface: Color(0xFFFFF4E8),
    mutedText: Color(0xFFD6BFB1),
    outline: Color(0xFF5B4943),
    fieldBorder: Color(0xFF9A8073),
    accent: Color(0xFFFFBE78),
    onAccent: Color(0xFF322010),
    appBar: Color(0xFF242020),
    onAppBar: Color(0xFFFFF4E8),
  );

  static const _copperClassic = StudioPalette(
    appearance: StudioAppearance.classic,
    canvas: Color(0xFF090909),
    surface: Color(0xFF1D1B19),
    raisedSurface: Color(0xFF302C26),
    fieldSurface: Color(0xFF27221D),
    onSurface: Color(0xFFFBF4E9),
    mutedText: Color(0xFFD8C5B1),
    outline: Color(0xFF5B5042),
    fieldBorder: Color(0xFF968271),
    accent: Color(0xFFF4B969),
    onAccent: Color(0xFF322010),
    appBar: Color(0xFF1D1B19),
    onAppBar: Color(0xFFFBF4E9),
  );

  static const _asterLight = StudioPalette(
    appearance: StudioAppearance.light,
    canvas: Color(0xFFFFFEFF),
    surface: Color(0xFFFFFFFF),
    raisedSurface: Color(0xFFFFFFFF),
    fieldSurface: Color(0xFFF7F1FC),
    onSurface: Color(0xFF251B31),
    mutedText: Color(0xFF6C597B),
    outline: Color(0xFFCEC2DA),
    fieldBorder: Color(0xFF9479AB),
    accent: Color(0xFF7444AA),
    onAccent: Colors.white,
    appBar: Color(0xFF302040),
    onAppBar: Colors.white,
  );

  static const _asterDark = StudioPalette(
    appearance: StudioAppearance.dark,
    canvas: Color(0xFF15121D),
    surface: Color(0xFF251F30),
    raisedSurface: Color(0xFF3C3048),
    fieldSurface: Color(0xFF30273A),
    onSurface: Color(0xFFF8F2FC),
    mutedText: Color(0xFFCBBFD7),
    outline: Color(0xFF5C506E),
    fieldBorder: Color(0xFF9885AD),
    accent: Color(0xFFD6ADFF),
    onAccent: Color(0xFF241332),
    appBar: Color(0xFF251F30),
    onAppBar: Color(0xFFF8F2FC),
  );

  static const _asterClassic = StudioPalette(
    appearance: StudioAppearance.classic,
    canvas: Color(0xFF08070B),
    surface: Color(0xFF1A1721),
    raisedSurface: Color(0xFF30283A),
    fieldSurface: Color(0xFF251F2D),
    onSurface: Color(0xFFF8F3FF),
    mutedText: Color(0xFFC7BFD2),
    outline: Color(0xFF61566F),
    fieldBorder: Color(0xFF9985B0),
    accent: Color(0xFFC8A1FF),
    onAccent: Color(0xFF21132C),
    appBar: Color(0xFF1A1721),
    onAppBar: Color(0xFFF8F3FF),
  );
}
