import 'package:subtitle_studio/database/models/models.dart';

/// Mutable subtitle entry used by raw/source editing surfaces.
///
/// Equality is value-based so controllers can cheaply ignore no-op updates.
class SubtitleEntry {
  String index;
  String startTime;
  String endTime;
  String text;

  SubtitleEntry({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  String toSrtString() {
    return '$index\n$startTime --> $endTime\n$text\n';
  }

  /// Parses one numbered SRT cue block.
  ///
  /// Accepts flexible whitespace around the arrow and both comma/dot
  /// millisecond separators while preserving the original timestamp strings.
  static SubtitleEntry? fromSrtText(String srtText) {
    final normalized = srtText
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    final lines = normalized.split('\n');
    if (lines.length < 3) return null;

    final index = lines.first.trim();
    if (!RegExp(r'^\d+$').hasMatch(index)) return null;

    final timingMatch = RegExp(
      r'^\s*(\d{1,3}:\d{2}:\d{2}[\.,]\d{3})\s*-->\s*'
      r'(\d{1,3}:\d{2}:\d{2}[\.,]\d{3})(?:\s+.*)?\s*$',
    ).firstMatch(lines[1]);

    if (timingMatch == null) return null;

    return SubtitleEntry(
      index: index,
      startTime: timingMatch.group(1)!,
      endTime: timingMatch.group(2)!,
      text: lines.skip(2).join('\n').trim(),
    );
  }

  static SubtitleEntry fromSubtitleLine(
    SubtitleLine line,
    int zeroBasedIndex,
  ) {
    return SubtitleEntry(
      index: (zeroBasedIndex + 1).toString(),
      startTime: line.startTime,
      endTime: line.endTime,
      text: line.edited ?? line.original,
    );
  }

  SubtitleEntry copyWith({
    String? index,
    String? startTime,
    String? endTime,
    String? text,
  }) {
    return SubtitleEntry(
      index: index ?? this.index,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SubtitleEntry &&
            other.index == index &&
            other.startTime == startTime &&
            other.endTime == endTime &&
            other.text == text;
  }

  @override
  int get hashCode => Object.hash(index, startTime, endTime, text);
}
