import 'package:characters/characters.dart';

/// A read-only projection of persisted subtitle cues for effect folding.
/// Source lines, timecodes, history and exported SRT are never changed.
class StudioDockEffectFrame {
  const StudioDockEffectFrame({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
    this.effectiveText,
  });

  final int id;
  final String start;
  final String end;
  final String original;
  final String edited;

  /// Imported SRT has no edited translation. An explicitly cleared edit,
  /// however, is different from a missing edit and must remain empty.
  final String? effectiveText;

  String get text => effectiveText ?? (edited.isEmpty ? original : edited);
}

/// Only effects expressible in SRT: successive timed cues with changing text
/// or SRT-compatible inline formatting. ASS/SSA scripts are not interpreted.
enum StudioDockEffectKind {
  karaoke,
  movingKaraoke,
  typewriter,
  activeTypewriter,
  wordReveal,
  lineReveal,
  reveal,
  erase,
  colorAnimation,
  blink,
  rainbow,
  scrambleReveal;

  String get label => switch (this) {
    StudioDockEffectKind.karaoke => 'Karaoke',
    StudioDockEffectKind.movingKaraoke => 'Moving karaoke',
    StudioDockEffectKind.typewriter => 'Typewriter',
    StudioDockEffectKind.activeTypewriter => 'Active-character typewriter',
    StudioDockEffectKind.wordReveal => 'Word reveal',
    StudioDockEffectKind.lineReveal => 'Line reveal',
    StudioDockEffectKind.reveal => 'Text reveal',
    StudioDockEffectKind.erase => 'Backspace / erase',
    StudioDockEffectKind.colorAnimation => 'Color transition',
    StudioDockEffectKind.blink => 'Blink',
    StudioDockEffectKind.rainbow => 'Rainbow text',
    StudioDockEffectKind.scrambleReveal => 'Scramble reveal',
  };
}

class StudioDockEffectGroup {
  const StudioDockEffectGroup({
    required this.frames,
    required this.kind,
    required this.previewText,
  });

  final List<StudioDockEffectFrame> frames;
  final StudioDockEffectKind kind;
  /// Full readable text; an external typewriter SRT may only have a short
  /// first frame in its `original` field.
  final String previewText;

  int get firstId => frames.first.id;
  int get lastId => frames.last.id;
  String get start => frames.first.start;
  String get end => frames.last.end;
  String get original => frames.first.original;
  int get length => frames.length;

  bool contains(int id) => id >= firstId && id <= lastId &&
      frames.any((frame) => frame.id == id);
}

/// Review marks remain attached to real SRT cues, never to a synthetic
/// collapsed row. This projection is shared by the grid and review sheet.
enum StudioDockEffectMarkState { none, partial, all }

abstract final class StudioDockEffectMarks {
  static StudioDockEffectMarkState state(
      StudioDockEffectGroup group, Set<int> markedCueIds) {
    final count = group.frames
        .where((frame) => markedCueIds.contains(frame.id)).length;
    if (count == 0) return StudioDockEffectMarkState.none;
    return count == group.length
        ? StudioDockEffectMarkState.all
        : StudioDockEffectMarkState.partial;
  }

  /// A collapsed row targets every persisted cue in its detected effect.
  /// Expanded rows pass no group here and target their one individual cue.
  static List<int> targets(int cueId, {StudioDockEffectGroup? collapsedGroup}) =>
      collapsedGroup == null
          ? [cueId]
          : [for (final frame in collapsedGroup.frames) frame.id];
}

/// Conservative pattern recognition for frame-by-frame SRT effects.
///
/// Detection uses visible text (including imported original-only SRT cues),
/// SRT font-color ranges, sequential indices and contiguous timing. Plain
/// animations need three short frames to avoid folding ordinary dialogue.
class StudioDockEffectGroups {
  const StudioDockEffectGroups._();

  static const _maxGapMs = 150;
  static const _maxPlainFrameMs = 1200;
  static const _maxStyledFrameMs = 6000;
  // The last exported cue can include up to 1000 ms of intentional end hold.
  static const _maxColorFrameMs = 1600;

  static List<StudioDockEffectGroup> detect(
      List<StudioDockEffectFrame> frames) {
    final groups = <StudioDockEffectGroup>[];
    final parsed = [for (final frame in frames) _SrtFrame.parse(frame)];
    final rawSteps = <StudioDockEffectKind?>[
      for (var i = 0; i < parsed.length - 1; i++)
        _step(parsed[i], parsed[i + 1]),
    ];
    final steps = List<StudioDockEffectKind?>.of(rawSteps);
    // A typewriter can reveal a newline in one frame, followed by the next
    // glyph in another. That one boundary must not split a single generated
    // effect into separate Typewriter / Line reveal groups. Genuine line-by-
    // line reveals contain successive line transitions instead.
    for (var i = 0; i < steps.length; i++) {
      if (rawSteps[i] == StudioDockEffectKind.lineReveal &&
          ((i > 0 && rawSteps[i - 1] == StudioDockEffectKind.typewriter) ||
           (i + 1 < rawSteps.length &&
               rawSteps[i + 1] == StudioDockEffectKind.typewriter))) {
        steps[i] = StudioDockEffectKind.typewriter;
      }
    }
    // A sampled typewriter frame may happen to finish an entire word; only
    // consistent word-by-word progression merits its own classification.
    for (var i = 0; i < steps.length; i++) {
      if (rawSteps[i] == StudioDockEffectKind.wordReveal &&
          ((i > 0 && rawSteps[i - 1] == StudioDockEffectKind.typewriter) ||
           (i + 1 < rawSteps.length &&
               rawSteps[i + 1] == StudioDockEffectKind.typewriter))) {
        steps[i] = StudioDockEffectKind.typewriter;
      }
    }
    var index = 0;
    while (index < frames.length - 1) {
      final blinkEnd = _blinkEnd(parsed, index);
      if (blinkEnd > index) {
        groups.add(StudioDockEffectGroup(
          frames: List.unmodifiable(frames.sublist(index, blinkEnd)),
          kind: StudioDockEffectKind.blink,
          previewText: parsed[index]!.plainText,
        ));
        index = blinkEnd;
        continue;
      }
      final first = parsed[index];
      final second = parsed[index + 1];
      final kind = steps[index];
      if (kind == null) {
        index++;
        continue;
      }

      var end = index + 2;
      while (end < parsed.length && steps[end - 1] == kind) {
        end++;
      }

      // Two short plain strings are weak evidence of an effect. Colored
      // reveals and unmistakable highlighted karaoke need only two frames.
      final formattedReveal = first != null && second != null &&
          first.fullColor != null && first.fullColor == second.fullColor;
      final minimum = switch (kind) {
        StudioDockEffectKind.karaoke => 2,
        StudioDockEffectKind.movingKaraoke => 2,
        StudioDockEffectKind.colorAnimation => 3,
        StudioDockEffectKind.blink => 4,
        StudioDockEffectKind.rainbow => 4,
        StudioDockEffectKind.scrambleReveal => 3,
        _ => formattedReveal ? 2 : 3,
      };
      if (end - index >= minimum) {
        final preview = kind == StudioDockEffectKind.erase
            ? parsed[index]!.plainText : parsed[end - 1]!.plainText;
        groups.add(StudioDockEffectGroup(
          frames: List.unmodifiable(frames.sublist(index, end)),
          kind: kind,
          previewText: preview,
        ));
        index = end;
      } else {
        index++;
      }
    }
    return groups;
  }

  static StudioDockEffectKind? _step(_SrtFrame? a, _SrtFrame? b) {
    if (a == null || b == null || !_adjacent(a, b)) {
      return null;
    }
    final aDuration = a.endMs - a.startMs;
    final bDuration = b.endMs - b.startMs;
    if (aDuration <= 0 || bDuration <= 0) return null;

    if (a.plainText == b.plainText) {
      // Multi-colored per-grapheme frames with an unchanged visible string.
      // Equal range boundaries and changed palettes avoid folding unrelated
      // formatted dialogue into one effect.
      if (aDuration <= _maxColorFrameMs && bDuration <= _maxColorFrameMs &&
          a.colorRanges.length >= 2 &&
          a.colorRanges.length == b.colorRanges.length &&
          a.colorRanges.first.start == 0 &&
          a.colorRanges.last.end == a.plainText.length &&
          b.colorRanges.first.start == 0 &&
          b.colorRanges.last.end == b.plainText.length &&
          List.generate(a.colorRanges.length, (i) => i).every((i) =>
            a.colorRanges[i].start == b.colorRanges[i].start &&
            a.colorRanges[i].end == b.colorRanges[i].end) &&
          List.generate(a.colorRanges.length, (i) => i).any((i) =>
            a.colorRanges[i].color != b.colorRanges[i].color)) {
        return StudioDockEffectKind.rainbow;
      }
      // Cumulative highlights and moving word/character karaoke windows.
      final x = a.highlight;
      final y = b.highlight;
      if (x != null && y != null && x.color == y.color &&
          aDuration <= _maxStyledFrameMs &&
          bDuration <= _maxStyledFrameMs &&
          y.start >= x.start && y.end > x.end) {
        return y.start > x.start ? StudioDockEffectKind.movingKaraoke
            : StudioDockEffectKind.karaoke;
      }
      // Per-cue color fade/pulse/flash. The entire text changes color but
      // not content. We require at least three adjacent frames later.
      if (a.fullColor != null && b.fullColor != null &&
          a.fullColor != b.fullColor &&
          aDuration <= _maxColorFrameMs && bDuration <= _maxColorFrameMs) {
        return StudioDockEffectKind.colorAnimation;
      }
      return null;
    }

    // A valid final SRT cue containing one space produces the empty screen
    // after a Backspace effect; keep that final frame in the folded group.
    if (b.plainText.trim().isEmpty && a.plainText.trim().isNotEmpty &&
        a.fullColor != null && a.fullColor == b.fullColor &&
        aDuration <= _maxStyledFrameMs && bDuration <= _maxStyledFrameMs) {
      return StudioDockEffectKind.erase;
    }

    // Plain reveals/erases may have no markup at all in imported SRT files.
    // Consistently colored whole-text effects are supported as well.
    if (a.activeCharacter && b.activeCharacter &&
        a.plainText.characters.length < b.plainText.characters.length &&
        b.plainText.startsWith(a.plainText)) {
      return StudioDockEffectKind.activeTypewriter;
    }
    if (a.fullColor == b.fullColor &&
        aDuration <= _maxStyledFrameMs && bDuration <= _maxStyledFrameMs &&
        _isScrambleStep(a.plainText, b.plainText)) {
      return StudioDockEffectKind.scrambleReveal;
    }
    if (a.fullColor != b.fullColor ||
        (a.highlight != null && a.fullColor == null) ||
        (b.highlight != null && b.fullColor == null) ||
        aDuration > (a.fullColor == null
            ? _maxPlainFrameMs : _maxStyledFrameMs) ||
        bDuration > (b.fullColor == null
            ? _maxPlainFrameMs : _maxStyledFrameMs)) {
      return null;
    }

    final before = a.plainText.characters.toList(growable: false);
    final after = b.plainText.characters.toList(growable: false);
    if (before.isEmpty || after.isEmpty) return null;
    if (before.length < after.length) {
      if (b.plainText.startsWith('${a.plainText}\n') &&
          a.plainText.trim().isNotEmpty) {
        return StudioDockEffectKind.lineReveal;
      }
      if (_startsWith(after, before)) {
        final added = b.plainText.substring(a.plainText.length);
        if (RegExp(r'^\s+\S+$', unicode: true).hasMatch(added) &&
            !a.plainText.endsWith(' ')) {
          return StudioDockEffectKind.wordReveal;
        }
        return StudioDockEffectKind.typewriter;
      }
      if (_endsWith(after, before)) return StudioDockEffectKind.reveal;
    } else if (before.length > after.length &&
        (_startsWith(before, after) || _endsWith(before, after))) {
      return StudioDockEffectKind.erase;
    }
    return null;
  }

  static bool _adjacent(_SrtFrame a, _SrtFrame b) =>
      b.cue.id == a.cue.id + 1 && b.startMs >= a.endMs &&
      b.startMs - a.endMs <= _maxGapMs;

  /// Blinking is the only useful SRT effect with empty cues. Four or more
  /// short alternating visible/empty frames prevent collapsing a normal pause
  /// between two repetitions of the same dialogue.
  static int _blinkEnd(List<_SrtFrame?> frames, int index) {
    final first = frames[index];
    if (first == null || first.plainText.trim().isEmpty ||
        !_shortBlinkFrame(first)) return index;
    var end = index + 1;
    var previous = first;
    var previousBlank = false;
    while (end < frames.length) {
      final current = frames[end];
      if (current == null || !_adjacent(previous, current) ||
          !_shortBlinkFrame(current)) break;
      final blank = current.plainText.trim().isEmpty;
      if (blank == previousBlank ||
          (!blank && current.plainText != first.plainText)) break;
      previous = current;
      previousBlank = blank;
      end++;
    }
    return end - index >= 4 ? end : index;
  }

  static bool _shortBlinkFrame(_SrtFrame frame) =>
      frame.endMs > frame.startMs &&
      frame.endMs - frame.startMs <= _maxColorFrameMs;

  static bool _startsWith(List<String> longer, List<String> shorter) {
    for (var i = 0; i < shorter.length; i++) {
      if (longer[i] != shorter[i]) return false;
    }
    return true;
  }

  static bool _endsWith(List<String> longer, List<String> shorter) {
    final offset = longer.length - shorter.length;
    for (var i = 0; i < shorter.length; i++) {
      if (longer[offset + i] != shorter[i]) return false;
    }
    return true;
  }

  static bool _isScrambleStep(String from, String to) {
    final a = from.characters.toList(growable: false);
    final b = to.characters.toList(growable: false);
    if (a.length != b.length || a.length < 3) return false;
    const placeholders = {'◈', '◇', '◆', '◉', '◌', '▣', '◍', '•'};
    var resolved = 0;
    for (var i = 0; i < a.length; i++) {
      if (placeholders.contains(a[i])) {
        if (!placeholders.contains(b[i])) resolved++;
      } else if (a[i] != b[i]) {
        return false;
      }
    }
    return resolved > 0;
  }
}

class _SrtFrame {
  const _SrtFrame({
    required this.cue,
    required this.startMs,
    required this.endMs,
    required this.plainText,
    required this.highlight,
    required this.colorRanges,
    required this.activeCharacter,
  });

  final StudioDockEffectFrame cue;
  final int startMs;
  final int endMs;
  final String plainText;
  final _ColorRange? highlight;
  final List<_ColorRange> colorRanges;
  final bool activeCharacter;

  String? get fullColor => highlight?.start == 0 &&
      highlight?.end == plainText.length ? highlight?.color : null;

  static final _srtTags = RegExp(r'<[^>]+>');
  static final _knownTag = RegExp(
      r'^<\s*(/?)\s*(font|b|i|u|br)\b([^>]*)>$', caseSensitive: false);
  static final _fontColor = RegExp(
      r'''\bcolor\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))''',
      caseSensitive: false);
  static final _time = RegExp(r'^(\d+):([0-5]?\d):([0-5]?\d)[,.](\d{1,3})$');

  static _SrtFrame? parse(StudioDockEffectFrame cue) {
    final startMs = _timeMs(cue.start);
    final endMs = _timeMs(cue.end);
    if (startMs == null || endMs == null) return null;

    final input = cue.text.replaceAll('\r\n', '\n');
    final plain = StringBuffer();
    final ranges = <_ColorRange>[];
    final colorStack = <String?>[];
    String? activeColor;
    var offset = 0;
    var cursor = 0;

    void append(String text) {
      if (text.isEmpty) return;
      plain.write(text);
      if (activeColor != null) {
        if (ranges.isNotEmpty && ranges.last.color == activeColor &&
            ranges.last.end == offset) {
          ranges[ranges.length - 1] =
              _ColorRange(ranges.last.start, offset + text.length, activeColor!);
        } else {
          ranges.add(_ColorRange(offset, offset + text.length, activeColor!));
        }
      }
      offset += text.length;
    }

    for (final token in _srtTags.allMatches(input)) {
      append(input.substring(cursor, token.start));
      final tag = _knownTag.firstMatch(token.group(0)!);
      // Unsupported tags may affect rendering; don't guess at their effects.
      if (tag == null) return null;
      final closing = tag.group(1)!.isNotEmpty;
      switch (tag.group(2)!.toLowerCase()) {
        case 'br':
          if (!closing) append('\n');
          break;
        case 'font':
          if (closing) {
            if (colorStack.isEmpty) return null;
            activeColor = colorStack.removeLast();
          } else {
            colorStack.add(activeColor);
            final attribute = _fontColor.firstMatch(tag.group(3)!);
            if (attribute != null) {
              activeColor = (attribute.group(1) ?? attribute.group(2) ??
                      attribute.group(3)!).toLowerCase();
            }
          }
          break;
        default:
          // Bold/italic/underline preserve visible text.
          break;
      }
      cursor = token.end;
    }
    append(input.substring(cursor));
    if (colorStack.isNotEmpty ||
        (plain.isEmpty && input.trim().isNotEmpty)) return null;
    return _SrtFrame(
      cue: cue,
      startMs: startMs,
      endMs: endMs,
      plainText: plain.toString(),
      highlight: ranges.length == 1 ? ranges.single : null,
      colorRanges: List.unmodifiable(ranges),
      activeCharacter: (ranges.length == 1 &&
              plain.toString().characters.length == 1 &&
              ranges.single.start == 0 && ranges.single.end == plain.length) ||
          (ranges.length == 2 && ranges.first.start == 0 &&
              ranges.first.end == ranges.last.start &&
              ranges.last.end == plain.length &&
              plain.toString().characters.isNotEmpty &&
              ranges.last.end - ranges.last.start ==
                  plain.toString().characters.last.length),
    );
  }

  static int? _timeMs(String input) {
    final match = _time.firstMatch(input.trim());
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final millis = int.parse(match.group(4)!.padRight(3, '0'));
    return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis;
  }
}

class _ColorRange {
  const _ColorRange(this.start, this.end, this.color);

  final int start;
  final int end;
  final String color;
}
