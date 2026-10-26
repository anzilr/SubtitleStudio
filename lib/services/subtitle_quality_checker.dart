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
enum SubtitleQualityFixKind { whitespace, balancedLineBreak }

class SubtitleQualityFix {
  const SubtitleQualityFix({
    required this.cueId,
    required this.before,
    required this.after,
    required this.description,
    this.kind = SubtitleQualityFixKind.whitespace,
    this.maxCharactersPerLine = 42,
  });

  final int cueId;
  final String before;
  final String after;
  final String description;
  final SubtitleQualityFixKind kind;
  final int maxCharactersPerLine;
}

/// An advisory proposal only. Timing changes need cross-cue confirmation and
/// are intentionally not accepted by the text-fix checkpoint writer.
class SubtitleQualityTimingSuggestion {
  const SubtitleQualityTimingSuggestion({
    required this.cueId,
    required this.followingCueId,
    required this.beforeEnd,
    required this.proposedEnd,
    required this.detail,
    required this.profile,
  });

  final int cueId;
  final int followingCueId;
  final String beforeEnd;
  final String proposedEnd;
  final String detail;
  /// Exact rule set that produced the proposal, for writer-side regeneration.
  final SubtitleQualityProfile profile;
}

class SubtitleQualityChecker {
  static final RegExp _timePattern = RegExp(
    r'^\s*(\d{1,3}):([0-5]\d):([0-5]\d)[,.](\d{3})\s*$',
  );
  static final RegExp _canonicalTimePattern = RegExp(
    r'^\d{2}:[0-5]\d:[0-5]\d,\d{3}$',
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

  /// Suggest a two-line split only for a single, unformatted, well-spaced
  /// paragraph. Split on an existing word boundary; never alter text or tags.
  static String? balancedLineBreak(
    String text, {
    int maxCharactersPerLine = 42,
  }) {
    final totalCharacters = text.characters.length;
    if (maxCharactersPerLine < 8 || maxCharactersPerLine > 300 ||
        text.isEmpty || text.trim() != text ||
        text.contains('\n') || text.contains('\r') || text.contains('\t') ||
        text.contains('\\') || text.contains('<') ||
        text.contains('{') || text.contains('}') ||
        normalizeSpaces(text) != text ||
        totalCharacters <= maxCharactersPerLine ||
        totalCharacters > maxCharactersPerLine * 2 + 1) {
      return null;
    }
    final words = text.split(' ');
    if (words.length < 4) return null;
    String? result;
    var bestDifference = 1 << 30;
    for (var i = 2; i <= words.length - 2; i++) {
      final left = words.take(i).join(' ');
      final right = words.skip(i).join(' ');
      final leftLength = left.characters.length;
      final rightLength = right.characters.length;
      if (leftLength > maxCharactersPerLine ||
          rightLength > maxCharactersPerLine) continue;
      final difference = (leftLength - rightLength).abs();
      if (difference < bestDifference) {
        result = '$left\n$right';
        bestDifference = difference;
      }
    }
    return result;
  }

  static List<SubtitleQualityFix> proposeSafeFixes(
      List<SubtitleQualityCue> cues, {
      SubtitleQualityProfile profile = const SubtitleQualityProfile(),
    }) {
    final suggestions = <SubtitleQualityFix>[];
    for (final cue in cues) {
      final whitespaceFix = normalizeSpaces(cue.text);
      if (whitespaceFix != cue.text) {
        suggestions.add(SubtitleQualityFix(
          cueId: cue.id,
          before: cue.text,
          after: whitespaceFix,
          description: 'Remove repeated and trailing spaces',
        ));
        continue;
      }
      if (profile.maxLines < 2) continue;
      final split = balancedLineBreak(cue.text,
          maxCharactersPerLine: profile.maxCharactersPerLine);
      if (split != null) {
        suggestions.add(SubtitleQualityFix(
          cueId: cue.id,
          before: cue.text,
          after: split,
          description: 'Balance text over two lines',
          kind: SubtitleQualityFixKind.balancedLineBreak,
          maxCharactersPerLine: profile.maxCharactersPerLine,
        ));
      }
    }
    return List.unmodifiable(suggestions);
  }

  static String _formatMilliseconds(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms ~/ 60000) % 60;
    final seconds = (ms ~/ 1000) % 60;
    final milliseconds = ms % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${milliseconds.toString().padLeft(3, '0')}';
  }

  /// Preview how an insufficient positive gap *could* be corrected by ending
  /// the preceding cue sooner. No change is applied or included in text fixes.
  /// Declines candidates that would violate minimum duration or CPS rules.
  static List<SubtitleQualityTimingSuggestion> proposeTimingSuggestions(
    List<SubtitleQualityCue> cues, {
    SubtitleQualityProfile profile = const SubtitleQualityProfile(),
  }) {
    final valid = <({SubtitleQualityCue cue, int start, int end})>[];
    for (final cue in cues) {
      final start = _milliseconds(cue.start);
      final end = _milliseconds(cue.end);
      if (start == null || end == null || start >= end) continue;
      valid.add((cue: cue, start: start, end: end));
    }
    valid.sort((a, b) => a.start.compareTo(b.start));
    final ideas = <SubtitleQualityTimingSuggestion>[];
    for (var i = 1; i < valid.length; i++) {
      final preceding = valid[i - 1];
      final next = valid[i];
      if (!_canonicalTimePattern.hasMatch(preceding.cue.start) ||
          !_canonicalTimePattern.hasMatch(preceding.cue.end) ||
          !_canonicalTimePattern.hasMatch(next.cue.start) ||
          !_canonicalTimePattern.hasMatch(next.cue.end) ||
          preceding.start >= 86400000 || next.start >= 86400000 ||
          preceding.end >= 86400000 || next.end >= 86400000) continue;
      final gap = next.start - preceding.end;
      if (gap < 0 || gap >= profile.minGapMs) continue;
      final proposedEnd = next.start - profile.minGapMs;
      final duration = proposedEnd - preceding.start;
      if (duration < profile.minDurationMs || duration <= 0) continue;
      final visible = visibleText(preceding.cue.text)
          .replaceAll('\n', ' ').trim();
      if (visible.characters.length * 1000 / duration >
          profile.maxCharactersPerSecond) continue;
      ideas.add(SubtitleQualityTimingSuggestion(
        cueId: preceding.cue.id,
        followingCueId: next.cue.id,
        beforeEnd: preceding.cue.end,
        proposedEnd: _formatMilliseconds(proposedEnd),
        profile: profile,
        detail: 'Leave ${profile.minGapMs} ms before subtitle '
            '#${next.cue.id}; shortens this subtitle by '
            '${profile.minGapMs - gap} ms.',
      ));
    }
    return List.unmodifiable(ideas);
  }

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
