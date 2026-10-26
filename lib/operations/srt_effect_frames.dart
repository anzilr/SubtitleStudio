import 'dart:math' as math;

import 'package:characters/characters.dart';

/// SRT contains no animation commands. An effect is therefore encoded as
/// successive timed SRT cues, each carrying a complete displayable frame.
/// This is also the source of truth for previews on mobile and Studio Dock.
abstract final class SrtEffectFrames {
  static const supported = <String>{
    'wordReveal', 'movingKaraoke', 'activeTypewriter',
    'backspace', 'lineReveal', 'colorTransition',
    'blinkFlash', 'rainbowText', 'scrambleReveal',
  };

  static const rainbowColors = <String>[
    'FF3B30', 'FF9500', 'FFD60A', '34C759',
    '00C7BE', '007AFF', 'AF52DE',
  ];

  /// Unrevealed characters cycle through symbols, never through parts of
  /// Unicode graphemes. Imported SRT can also be recognized from this pattern.
  static const scrambleSymbols = <String>[
    '◈', '◇', '◆', '◉', '◌', '▣', '◍', '•',
  ];

  static List<String> build({
    required String effect,
    required String text,
    required String color,
    String unit = 'word',
    String alternateColor = 'FFFF00',
    required int availableMilliseconds,
  }) {
    if (!supported.contains(effect) || availableMilliseconds <= 0) return [];
    final clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
    if (clean.trim().isEmpty) return [];
    final glyphs = clean.characters.toList(growable: false);
    final words = RegExp(r'\S+', unicode: true).allMatches(clean).toList();
    final movingRanges = <({int start, int end})>[];
    if (effect == 'movingKaraoke' && unit == 'character') {
      // Dart offsets are UTF-16 code units. Calculate them only at complete
      // grapheme boundaries, never in the middle of Malayalam or emoji.
      var offset = 0;
      for (final glyph in glyphs) {
        if (glyph.trim().isNotEmpty) {
          movingRanges.add((start: offset, end: offset + glyph.length));
        }
        offset += glyph.length;
      }
    } else {
      for (final word in words) {
        movingRanges.add((start: word.start, end: word.end));
      }
    }
    final lines = clean.split('\n');
    if (effect == 'blinkFlash' && availableMilliseconds < 300) return [];
    if (effect == 'rainbowText' &&
        (glyphs.length < 2 || availableMilliseconds < 240)) return [];
    if (effect == 'scrambleReveal' &&
        (glyphs.length < 3 || availableMilliseconds < 180)) return [];
    final scramblePalette = scrambleSymbols
        .where((symbol) => !clean.contains(symbol)).toList(growable: false);
    if (effect == 'scrambleReveal' && scramblePalette.isEmpty) return [];
    final blinkLimit = math.min(9, availableMilliseconds ~/ 90);
    final blinkFrames = blinkLimit.isEven ? blinkLimit - 1 : blinkLimit;
    final steps = switch (effect) {
      'wordReveal' => words.length,
      'movingKaraoke' => movingRanges.length,
      'lineReveal' => lines.length,
      'colorTransition' => 12,
      'blinkFlash' => math.max(5, blinkFrames),
      'rainbowText' => 7,
      'scrambleReveal' => glyphs.where((glyph) => glyph.trim().isNotEmpty).length,
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
        'movingKaraoke' => _fontMoving(clean, movingRanges[step - 1], color),
        'activeTypewriter' => _activeGlyph(glyphs, step, color, alternateColor),
        'backspace' => _font(glyphs.take(math.max(0, glyphs.length - step + 1))
            .join('').isEmpty ? ' ' : glyphs.take(
              math.max(0, glyphs.length - step + 1)).join(''), color),
        'lineReveal' => _font(lines.take(step).join('\n'), color),
        'colorTransition' => _font(clean, _blend(color, alternateColor,
            count == 1 ? 1 : (frame - 1) / (count - 1))),
        'blinkFlash' => frame.isOdd ? _font(clean, color) : ' ',
        'rainbowText' => _rainbow(glyphs, step - 1),
        'scrambleReveal' => _scramble(glyphs, step, frame, color,
            scramblePalette),
        _ => clean,
      };
      result.add(content);
    }
    return List.unmodifiable(result);
  }

  static String _font(String text, String color) =>
      '<font color="#${_rgb(color)}">$text</font>';

  static String _fontMoving(String text, ({int start, int end}) range,
      String color) => '${text.substring(0, range.start)}'
      '${_font(text.substring(range.start, range.end), color)}'
      '${text.substring(range.end)}';

  static String _activeGlyph(List<String> glyphs, int count,
      String color, String alternateColor) {
    final visible = glyphs.take(count).toList();
    if (visible.isEmpty) return '';
    return '${visible.length > 1 ? _font(visible.take(visible.length - 1).join(), color) : ''}'
        '${_font(visible.last, alternateColor)}';
  }

  static String _rainbow(List<String> glyphs, int phase) =>
      [for (var i = 0; i < glyphs.length; i++)
        _font(glyphs[i], rainbowColors[(i + phase) % rainbowColors.length])]
          .join();

  static String _scramble(List<String> glyphs, int revealed, int frame,
      String color, List<String> palette) {
    var meaningful = 0;
    return _font([
      for (var i = 0; i < glyphs.length; i++)
        if (glyphs[i].trim().isEmpty)
          glyphs[i]
        else if (++meaningful <= revealed)
          glyphs[i]
        else
          palette[(i * 3 + frame) % palette.length],
    ].join(), color);
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
