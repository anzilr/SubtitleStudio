/// Read-only subtitle quality checks shared by desktop and mobile callers.
///
/// The checker never rewrites text or timing. A future fix planner must present
/// changes for explicit approval and commit them through checkpoint history.
enum SubtitleQualityIssueType {
  invalidTimecode,
  invalidDuration,
  overlap,
  insufficientGap,
  shortDuration,
  longDuration,
  fastReading,
  longLine,
  tooManyLines,
  emptyText,
}

extension SubtitleQualityIssueLabel on SubtitleQualityIssueType {
  String get label => switch (this) {
        SubtitleQualityIssueType.invalidTimecode => 'Invalid timecode',
        SubtitleQualityIssueType.invalidDuration => 'Invalid duration',
        SubtitleQualityIssueType.overlap => 'Overlapping subtitles',
        SubtitleQualityIssueType.insufficientGap => 'Gap too short',
        SubtitleQualityIssueType.shortDuration => 'Duration too short',
        SubtitleQualityIssueType.longDuration => 'Duration too long',
        SubtitleQualityIssueType.fastReading => 'Reading speed',
        SubtitleQualityIssueType.longLine => 'Line too long',
        SubtitleQualityIssueType.tooManyLines => 'Too many lines',
        SubtitleQualityIssueType.emptyText => 'Empty text',
      };
}

class SubtitleQualityCue {
  const SubtitleQualityCue({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  final int id;
  final String start;
  final String end;
  final String text;
}

class SubtitleQualityProfile {
  const SubtitleQualityProfile({
    this.maxCharactersPerSecond = 20,
    this.maxCharactersPerLine = 42,
    this.maxLines = 2,
    this.minDurationMs = 1000,
    this.maxDurationMs = 7000,
    this.minGapMs = 80,
  })  : assert(maxCharactersPerSecond > 0),
        assert(maxCharactersPerLine > 0),
        assert(maxLines > 0),
        assert(minDurationMs >= 0),
        assert(maxDurationMs > minDurationMs),
        assert(minGapMs >= 0);

  final double maxCharactersPerSecond;
  final int maxCharactersPerLine;
  final int maxLines;
  final int minDurationMs;
  final int maxDurationMs;
  final int minGapMs;
}

class SubtitleQualityIssue {
  const SubtitleQualityIssue({
    required this.cueId,
    required this.type,
    required this.detail,
    required this.text,
  });

  final int cueId;
  final SubtitleQualityIssueType type;
  final String detail;
  final String text;
}

class SubtitleQualityReport {
  SubtitleQualityReport(List<SubtitleQualityIssue> issues)
      : issues = List.unmodifiable(issues);

  final List<SubtitleQualityIssue> issues;

  int get affectedCues => issues.map((issue) => issue.cueId).toSet().length;

  int count(SubtitleQualityIssueType type) =>
      issues.where((issue) => issue.type == type).length;
}

class SubtitleQualityChecker {
  static final RegExp _timePattern = RegExp(
    r'^\s*(\d{1,3}):([0-5]\d):([0-5]\d)[,.](\d{3})\s*$',
  );
  static final RegExp _htmlTags = RegExp(r'<[^>]*>');
  static final RegExp _assTags = RegExp(r'\{\\[^}]*\}');

  static int? _milliseconds(String value) {
    final match = _timePattern.firstMatch(value);
    if (match == null) return null;
    return (((int.parse(match[1]!) * 60 + int.parse(match[2]!)) * 60 +
                    int.parse(match[3]!)) *
                1000) +
        int.parse(match[4]!);
  }

  /// Strip supported formatting tags for *measurement only*. Source cues are
  /// retained verbatim, including deliberate blank lines and style markers.
  static String visibleText(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(_htmlTags, '')
      .replaceAll(_assTags, '');

  static SubtitleQualityReport scan(
    List<SubtitleQualityCue> cues, {
    SubtitleQualityProfile profile = const SubtitleQualityProfile(),
  }) {
    final issues = <SubtitleQualityIssue>[];
    final positions = <({int index, int start, int end})>[];

    for (var index = 0; index < cues.length; index++) {
      final cue = cues[index];
      final text = visibleText(cue.text);
      void add(SubtitleQualityIssueType type, String detail) {
        issues.add(SubtitleQualityIssue(
          cueId: cue.id, type: type, detail: detail, text: text.trim(),
        ));
      }

      final start = _milliseconds(cue.start);
      final end = _milliseconds(cue.end);
      if (start == null || end == null) {
        add(SubtitleQualityIssueType.invalidTimecode,
            'Start or end does not match HH:mm:ss,SSS.');
      } else if (end <= start) {
        add(SubtitleQualityIssueType.invalidDuration,
            'End must be later than start.');
      } else {
        positions.add((index: index, start: start, end: end));
        final duration = end - start;
        if (duration < profile.minDurationMs) {
          add(SubtitleQualityIssueType.shortDuration,
              '$duration ms · minimum ${profile.minDurationMs} ms');
        } else if (duration > profile.maxDurationMs) {
          add(SubtitleQualityIssueType.longDuration,
              '$duration ms · maximum ${profile.maxDurationMs} ms');
        }
        if (text.trim().isNotEmpty) {
          final charCount = text.replaceAll('\n', ' ').trim().runes.length;
          final cps = charCount * 1000 / duration;
          if (cps > profile.maxCharactersPerSecond) {
            add(SubtitleQualityIssueType.fastReading,
                '${cps.toStringAsFixed(1)} CPS · limit '
                '${profile.maxCharactersPerSecond.toStringAsFixed(1)} CPS');
          }
        }
      }

      if (text.trim().isEmpty) {
        add(SubtitleQualityIssueType.emptyText, 'No visible subtitle text.');
      } else {
        final lines = text.split('\n');
        if (lines.length > profile.maxLines) {
          add(SubtitleQualityIssueType.tooManyLines,
              '${lines.length} lines · maximum ${profile.maxLines}');
        }
        final longest = lines.map((line) => line.trim().runes.length)
            .reduce((a, b) => a > b ? a : b);
        if (longest > profile.maxCharactersPerLine) {
          add(SubtitleQualityIssueType.longLine,
              '$longest characters · limit ${profile.maxCharactersPerLine}');
        }
      }
    }

    // Analyze chronology, not display order; edits/imports may leave cue IDs
    // or source ordering different from their actual timestamps.
    positions.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.index.compareTo(b.index);
    });
    int? maxEnd;
    for (final position in positions) {
      if (maxEnd != null) {
        final gap = position.start - maxEnd;
        final cue = cues[position.index];
        if (gap < 0) {
          issues.add(SubtitleQualityIssue(
            cueId: cue.id,
            type: SubtitleQualityIssueType.overlap,
            detail: 'Overlaps an earlier subtitle by ${-gap} ms.',
            text: visibleText(cue.text).trim(),
          ));
        } else if (gap < profile.minGapMs) {
          issues.add(SubtitleQualityIssue(
            cueId: cue.id,
            type: SubtitleQualityIssueType.insufficientGap,
            detail: '$gap ms · minimum ${profile.minGapMs} ms',
            text: visibleText(cue.text).trim(),
          ));
        }
      }
      if (maxEnd == null || position.end > maxEnd) maxEnd = position.end;
    }

    final order = {for (var i = 0; i < cues.length; i++) cues[i].id: i};
    issues.sort((a, b) {
      final byCue = (order[a.cueId] ?? 0).compareTo(order[b.cueId] ?? 0);
      return byCue != 0 ? byCue : a.type.index.compareTo(b.type.index);
    });
    return SubtitleQualityReport(issues);
  }
}
