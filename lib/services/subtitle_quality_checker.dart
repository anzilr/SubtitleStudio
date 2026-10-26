import 'dart:convert';

import 'package:characters/characters.dart';

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
  unnecessaryWhitespace,
  repeatedText,
  outOfSequence,
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
        SubtitleQualityIssueType.unnecessaryWhitespace => 'Unnecessary spaces',
        SubtitleQualityIssueType.repeatedText => 'Repeated subtitle text',
        SubtitleQualityIssueType.outOfSequence => 'Out-of-order timecode',
      };
}

enum SubtitleQualityPreset { general, streaming, relaxed, custom }

extension SubtitleQualityPresetDetails on SubtitleQualityPreset {
  String get label => switch (this) {
        SubtitleQualityPreset.general => 'General',
        SubtitleQualityPreset.streaming => 'Streaming',
        SubtitleQualityPreset.relaxed => 'Relaxed',
        SubtitleQualityPreset.custom => 'Custom',
      };

  SubtitleQualityProfile get profile => switch (this) {
        SubtitleQualityPreset.general => const SubtitleQualityProfile(),
        SubtitleQualityPreset.streaming => const SubtitleQualityProfile(
            maxCharactersPerSecond: 17,
            maxCharactersPerLine: 42,
            minDurationMs: 1000,
            maxDurationMs: 7000,
            minGapMs: 83),
        SubtitleQualityPreset.relaxed => const SubtitleQualityProfile(
            maxCharactersPerSecond: 25,
            maxCharactersPerLine: 50,
            minDurationMs: 700,
            maxDurationMs: 9000,
            minGapMs: 40),
        SubtitleQualityPreset.custom => const SubtitleQualityProfile(),
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

  /// Persist custom limits independently of the active built-in preset.
  String encode() => jsonEncode({
        'maxCharactersPerSecond': maxCharactersPerSecond,
        'maxCharactersPerLine': maxCharactersPerLine,
        'maxLines': maxLines,
        'minDurationMs': minDurationMs,
        'maxDurationMs': maxDurationMs,
        'minGapMs': minGapMs,
      });

  /// A damaged or outdated stored profile must not break quality review.
  static SubtitleQualityProfile decode(String? encoded) {
    if (encoded == null) return const SubtitleQualityProfile();
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) {
        return const SubtitleQualityProfile();
      }
      final cps = value['maxCharactersPerSecond'];
      final line = value['maxCharactersPerLine'];
      final lines = value['maxLines'];
      final minMs = value['minDurationMs'];
      final maxMs = value['maxDurationMs'];
      final gapMs = value['minGapMs'];
      if (cps is! num || line is! int || lines is! int ||
          minMs is! int || maxMs is! int || gapMs is! int ||
          !cps.isFinite || cps <= 0 || cps > 100 ||
          line <= 0 || line > 300 || lines <= 0 || lines > 20 ||
          minMs < 0 || maxMs <= minMs || maxMs > 600000 ||
          gapMs < 0 || gapMs > 10000) {
        return const SubtitleQualityProfile();
      }
      return SubtitleQualityProfile(
        maxCharactersPerSecond: cps.toDouble(),
        maxCharactersPerLine: line,
        maxLines: lines,
        minDurationMs: minMs,
        maxDurationMs: maxMs,
        minGapMs: gapMs,
      );
    } on FormatException {
      return const SubtitleQualityProfile();
    } on TypeError {
      return const SubtitleQualityProfile();
    }
  }
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

/// One exact-before/exact-after proposal, safe to preview or select. The
/// writer must revalidate [before] against the current persisted cue.
class SubtitleQualityFix {
  const SubtitleQualityFix({
    required this.cueId,
    required this.before,
    required this.after,
    required this.description,
  });

  final int cueId;
  final String before;
  final String after;
  final String description;
}

class SubtitleQualityChecker {
  static final RegExp _timePattern = RegExp(
    r'^\s*(\d{1,3}):([0-5]\d):([0-5]\d)[,.](\d{3})\s*$',
  );
  static final RegExp _htmlTags = RegExp(r'<[^>]*>');
  static final RegExp _assTags = RegExp(r'\{\\[^}]*\}');
  static final RegExp _formatTags = RegExp(r'<[^>]*>|\{\\[^}]*\}');

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

  /// Normalize only plain-text spans; tags are copied byte-for-byte. Line
  /// breaks are also retained, including deliberately empty subtitle rows.
  static String normalizeSpaces(String text) {
    final out = StringBuffer();
    var cursor = 0;
    for (final tag in _formatTags.allMatches(text)) {
      out.write(_normalizePlainSpaces(text.substring(cursor, tag.start)));
      out.write(tag.group(0));
      cursor = tag.end;
    }
    out.write(_normalizePlainSpaces(text.substring(cursor)));
    return out.toString().replaceAll(RegExp(r'[ \t]+(?=\r?\n|$)'), '');
  }

  static String _normalizePlainSpaces(String text) => text
      .replaceAll(RegExp(r' {2,}'), ' ');

  static List<SubtitleQualityFix> proposeSafeFixes(
      List<SubtitleQualityCue> cues) => List.unmodifiable([
        for (final cue in cues)
          if (normalizeSpaces(cue.text) != cue.text)
            SubtitleQualityFix(
              cueId: cue.id,
              before: cue.text,
              after: normalizeSpaces(cue.text),
              description: 'Remove repeated and trailing spaces',
            ),
      ]);

  static SubtitleQualityReport scan(
    List<SubtitleQualityCue> cues, {
    SubtitleQualityProfile profile = const SubtitleQualityProfile(),
  }) {
    final issues = <SubtitleQualityIssue>[];
    final positions = <({int index, int start, int end})>[];
    int? previousFileStart;

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
      if (start != null) {
        if (previousFileStart != null && start < previousFileStart) {
          add(SubtitleQualityIssueType.outOfSequence,
              'This subtitle begins before the preceding subtitle in the file.');
        }
        previousFileStart = start;
      }
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
          final charCount = text.replaceAll('\n', ' ').trim().characters.length;
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
        final longest = lines.map((line) => line.trim().characters.length)
            .reduce((a, b) => a > b ? a : b);
        if (longest > profile.maxCharactersPerLine) {
          add(SubtitleQualityIssueType.longLine,
              '$longest characters · limit ${profile.maxCharactersPerLine}');
        }
      }
      if (normalizeSpaces(cue.text) != cue.text) {
        add(SubtitleQualityIssueType.unnecessaryWhitespace,
            'Repeated or trailing spaces can be simplified.');
      }
    }

    // Analyze chronology, not display order; edits/imports may leave cue IDs
    // or source ordering different from their actual timestamps.
    positions.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.index.compareTo(b.index);
    });
    int? maxEnd;
    String? precedingText;
    int? precedingCueId;
    for (final position in positions) {
      final cue = cues[position.index];
      final normalized = visibleText(cue.text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toLowerCase();
      if (normalized.isNotEmpty && normalized == precedingText) {
        issues.add(SubtitleQualityIssue(
          cueId: cue.id,
          type: SubtitleQualityIssueType.repeatedText,
          detail: 'Same text as subtitle #$precedingCueId. '
              'Check whether the repetition is intentional.',
          text: visibleText(cue.text).trim(),
        ));
      }
      precedingText = normalized;
      precedingCueId = cue.id;
      if (maxEnd != null) {
        final gap = position.start - maxEnd;
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
