import 'dart:math' as math;

import 'package:characters/characters.dart';

/// SRT contains no animation commands. An effect is therefore encoded as
/// successive timed SRT cues, each carrying a complete displayable frame.
/// This is also the source of truth for previews on mobile and Studio Dock.
abstract final class SrtEffectFrames {
  static const supported = <String>{
    'wordReveal', 'movingKaraoke', 'activeTypewriter',
    'backspace', 'lineReveal', 'colorTransition',
  };

  static List<String> build({
    required String effect,
    required String text,
    required String color,
    String alternateColor = 'FFFF00',
    required int availableMilliseconds,
  }) {
    if (!supported.contains(effect) || availableMilliseconds <= 0) return [];
    final clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
    if (clean.trim().isEmpty) return [];
    final glyphs = clean.characters.toList(growable: false);
    final words = RegExp(r'\S+', unicode: true).allMatches(clean).toList();
    final lines = clean.split('\n');
    final steps = switch (effect) {
      'wordReveal' || 'movingKaraoke' => words.length,
      'lineReveal' => lines.length,
      'colorTransition' => 12,
      'backspace' => glyphs.length + 1,
      _ => glyphs.length,
    };
    // Show no more than ~16 different frames per second. Sampling never
    // divides a grapheme (Malayalam clusters, ZWJ emoji, combining marks).
    final count = math.min(steps, math.max(1, availableMilliseconds ~/ 60));
    final result = <String>[];
    for (var frame = 1; frame <= count; frame++) {
      final step = (frame * steps / count).ceil();
      final content = switch (effect) {
        'wordReveal' => _font(step == words.length
            ? clean : clean.substring(0, words[step - 1].end), color),
        'movingKaraoke' => _fontMoving(clean, words[step - 1], color),
        'activeTypewriter' => _activeGlyph(glyphs, step, color, alternateColor),
        'backspace' => _font(glyphs.take(math.max(0, glyphs.length - step + 1))
            .join('').isEmpty ? ' ' : glyphs.take(
              math.max(0, glyphs.length - step + 1)).join(''), color),
        'lineReveal' => _font(lines.take(step).join('\n'), color),
        'colorTransition' => _font(clean, _blend(color, alternateColor,
            count == 1 ? 1 : (frame - 1) / (count - 1))),
        _ => clean,
      };
      result.add(content);
    }
    return List.unmodifiable(result);
  }

  static String _font(String text, String color) =>
      '<font color="#${_rgb(color)}">$text</font>';

  static String _fontMoving(String text, RegExpMatch match, String color) =>
      '${text.substring(0, match.start)}'
      '${_font(text.substring(match.start, match.end), color)}'
      '${text.substring(match.end)}';

  static String _activeGlyph(List<String> glyphs, int count,
      String color, String alternateColor) {
    final visible = glyphs.take(count).toList();
    if (visible.isEmpty) return '';
    return '${visible.length > 1 ? _font(visible.take(visible.length - 1).join(), color) : ''}'
        '${_font(visible.last, alternateColor)}';
  }

  static String _rgb(String raw) {
    final digits = raw.replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(digits)) return 'FFFFFF';
    return digits.toUpperCase();
  }

  static String _blend(String from, String to, double fraction) {
    final start = int.parse(_rgb(from), radix: 16);
    final end = int.parse(_rgb(to), radix: 16);
    int channel(int shift) {
      final a = (start >> shift) & 0xff;
      final b = (end >> shift) & 0xff;
      return (a + (b - a) * fraction).round().clamp(0, 255);
    }
    return ((channel(16) << 16) | (channel(8) << 8) | channel(0))
        .toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}
