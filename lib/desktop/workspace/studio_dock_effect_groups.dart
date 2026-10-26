/// A read-only projection of persisted subtitle cues for effect folding.
/// No source line, timecode, checkpoint, or export content is modified.
class StudioDockEffectFrame {
  const StudioDockEffectFrame({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    required this.edited,
  });

  final int id;
  final String start;
  final String end;
  final String original;
  final String edited;
}

enum StudioDockEffectKind { karaoke, typewriter }

class StudioDockEffectGroup {
  const StudioDockEffectGroup({
    required this.frames,
    required this.kind,
  });

  final List<StudioDockEffectFrame> frames;
  final StudioDockEffectKind kind;

  int get firstId => frames.first.id;
  int get lastId => frames.last.id;
  String get start => frames.first.start;
  String get end => frames.last.end;
  String get original => frames.first.original;
  int get length => frames.length;

  bool contains(int id) => id >= firstId && id <= lastId &&
      frames.any((frame) => frame.id == id);
}

/// Recognizes the exact progressive font-tag structures emitted by the
/// shared mobile/desktop effect generators. Ordinary text and coincidentally
/// adjacent same-source subtitles are never grouped on timing alone.
class StudioDockEffectGroups {
  const StudioDockEffectGroups._();

  static final RegExp _framePattern = RegExp(
    r'^([\s\S]*?)<font color="#([a-fA-F0-9]{6,8})">([\s\S]*?)</font>([\s\S]*)$',
  );

  static List<StudioDockEffectGroup> detect(
      List<StudioDockEffectFrame> frames) {
    final groups = <StudioDockEffectGroup>[];
    var index = 0;
    while (index < frames.length - 1) {
      final first = _parse(frames[index]);
      final next = _parse(frames[index + 1]);
      final kind = _nextStep(first, next);
      if (kind == null) {
        index++;
        continue;
      }
      var end = index + 2;
      var previous = next;
      while (end < frames.length) {
        final current = _parse(frames[end]);
        if (_nextStep(previous, current) != kind) break;
        previous = current;
        end++;
      }
      groups.add(StudioDockEffectGroup(
        frames: List.unmodifiable(frames.sublist(index, end)),
        kind: kind,
      ));
      index = end;
    }
    return groups;
  }

  static _ParsedEffectFrame? _parse(StudioDockEffectFrame cue) {
    final match = _framePattern.firstMatch(cue.edited);
    if (match == null || (match.group(3)?.isEmpty ?? true)) return null;
    return _ParsedEffectFrame(
      cue: cue,
      leading: match.group(1)!,
      color: match.group(2)!,
      highlighted: match.group(3)!,
      remaining: match.group(4)!,
    );
  }

  static StudioDockEffectKind? _nextStep(
      _ParsedEffectFrame? previous, _ParsedEffectFrame? next) {
    if (previous == null || next == null) return null;
    final a = previous.cue;
    final b = next.cue;
    if (b.id != a.id + 1 || a.end != b.start ||
        a.original != b.original || previous.color != next.color ||
        previous.leading != next.leading ||
        !next.highlighted.startsWith(previous.highlighted) ||
        next.highlighted.length <= previous.highlighted.length) {
      return null;
    }
    if (previous.highlighted + previous.remaining ==
        next.highlighted + next.remaining) {
      return StudioDockEffectKind.karaoke;
    }
    if (previous.remaining.isEmpty && next.remaining.isEmpty) {
      return StudioDockEffectKind.typewriter;
    }
    return null;
  }
}

class _ParsedEffectFrame {
  const _ParsedEffectFrame({
    required this.cue,
    required this.leading,
    required this.color,
    required this.highlighted,
    required this.remaining,
  });

  final StudioDockEffectFrame cue;
  final String leading;
  final String color;
  final String highlighted;
  final String remaining;
}
