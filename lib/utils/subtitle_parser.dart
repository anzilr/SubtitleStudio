// Simple subtitle class for secondary subtitles (no database IDs needed)
class SimpleSubtitleLine {
  final int index;
  final String startTime;
  final String endTime;
  final String text;

  SimpleSubtitleLine({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}

class SubtitleParser {
  // Parse SRT format
  static List<SimpleSubtitleLine> parseSrt(String content) {
    final normalized = _normalizeSubtitleText(content);
    final lines = normalized.split('\n');
    final subtitles = <SimpleSubtitleLine>[];

    int cursor = 0;
    int generatedIndex = 1;

    while (cursor < lines.length) {
      while (cursor < lines.length && lines[cursor].trim().isEmpty) {
        cursor++;
      }
      if (cursor >= lines.length) break;

      int? cueIndex;
      final current = lines[cursor].trim();
      if (RegExp(r'^\d+$').hasMatch(current) &&
          cursor + 1 < lines.length &&
          _parseCueTimingLine(lines[cursor + 1], allowShortHours: false) !=
              null) {
        cueIndex = int.tryParse(current);
        cursor++;
      }

      if (cursor >= lines.length) break;
      final timing = _parseCueTimingLine(
        lines[cursor],
        allowShortHours: false,
      );
      if (timing == null) {
        cursor++;
        continue;
      }
      cursor++;

      final textLines = <String>[];
      while (cursor < lines.length) {
        if (lines[cursor].trim().isEmpty) {
          break;
        }

        // Tolerate SRT files that omit the blank separator between cues.
        final looksLikeNextNumberedCue =
            RegExp(r'^\d+$').hasMatch(lines[cursor].trim()) &&
            cursor + 1 < lines.length &&
            _parseCueTimingLine(
                  lines[cursor + 1],
                  allowShortHours: false,
                ) !=
                null;
        final looksLikeNextUnnumberedCue =
            _parseCueTimingLine(
                  lines[cursor],
                  allowShortHours: false,
                ) !=
                null;

        if (looksLikeNextNumberedCue || looksLikeNextUnnumberedCue) {
          break;
        }

        textLines.add(lines[cursor]);
        cursor++;
      }

      subtitles.add(
        SimpleSubtitleLine(
          index: cueIndex ?? generatedIndex,
          startTime: timing.$1,
          endTime: timing.$2,
          text: textLines.join('\n'),
        ),
      );
      generatedIndex = (cueIndex ?? generatedIndex) + 1;
    }

    return subtitles;
  }

  // Parse VTT format
  static List<SimpleSubtitleLine> parseVtt(String content) {
    final normalized = _normalizeSubtitleText(content);
    final lines = normalized.split('\n');
    final subtitles = <SimpleSubtitleLine>[];

    int cursor = 0;
    int generatedIndex = 1;

    if (lines.isNotEmpty && lines.first.trim().startsWith('WEBVTT')) {
      cursor = 1;
      while (cursor < lines.length && lines[cursor].trim().isNotEmpty) {
        cursor++;
      }
    }

    while (cursor < lines.length) {
      while (cursor < lines.length && lines[cursor].trim().isEmpty) {
        cursor++;
      }
      if (cursor >= lines.length) break;

      final blockHeader = lines[cursor].trim();
      if (blockHeader == 'STYLE' ||
          blockHeader == 'REGION' ||
          blockHeader.startsWith('NOTE')) {
        while (cursor < lines.length && lines[cursor].trim().isNotEmpty) {
          cursor++;
        }
        continue;
      }

      String? cueIdentifier;
      var timing = _parseCueTimingLine(
        lines[cursor],
        allowShortHours: true,
      );

      if (timing == null && cursor + 1 < lines.length) {
        cueIdentifier = lines[cursor].trim();
        cursor++;
        timing = _parseCueTimingLine(
          lines[cursor],
          allowShortHours: true,
        );
      }

      if (timing == null) {
        cursor++;
        continue;
      }
      cursor++;

      final textLines = <String>[];
      while (cursor < lines.length && lines[cursor].trim().isNotEmpty) {
        textLines.add(lines[cursor]);
        cursor++;
      }

      final parsedIdentifier = cueIdentifier == null
          ? null
          : int.tryParse(cueIdentifier);

      final text = textLines
          .join('\n')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '');

      subtitles.add(
        SimpleSubtitleLine(
          index: parsedIdentifier ?? generatedIndex,
          startTime: timing.$1,
          endTime: timing.$2,
          text: text,
        ),
      );
      generatedIndex = (parsedIdentifier ?? generatedIndex) + 1;
    }

    return subtitles;
  }

  static String _normalizeSubtitleText(String content) {
    return content
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  /// Parses a cue timing line and returns normalized HH:MM:SS.mmm values.
  ///
  /// WebVTT permits MM:SS.mmm, while SRT normally includes hours. Both comma
  /// and dot millisecond separators are accepted because real-world SRT files
  /// frequently mix them.
  static (String, String)? _parseCueTimingLine(
    String line, {
    required bool allowShortHours,
  }) {
    final timestampPattern = allowShortHours
        ? r'(?:\d{1,3}:)?\d{2}:\d{2}[\.,]\d{3}'
        : r'\d{1,3}:\d{2}:\d{2}[\.,]\d{3}';

    final match = RegExp(
      '^\\s*($timestampPattern)\\s*-->\\s*($timestampPattern)(?:\\s+.*)?\\s*\$',
    ).firstMatch(line);

    if (match == null) return null;

    final start = _normalizeCueTimestamp(match.group(1)!);
    final end = _normalizeCueTimestamp(match.group(2)!);
    return (start, end);
  }

  static String _normalizeCueTimestamp(String value) {
    final normalized = value.replaceAll(',', '.');
    final parts = normalized.split(':');

    if (parts.length == 2) {
      return '00:${parts[0].padLeft(2, '0')}:${parts[1]}';
    }

    if (parts.length == 3) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:${parts[2]}';
    }

    return normalized;
  }

  // Parse ASS/SSA format
  static List<SimpleSubtitleLine> parseAss(String content) {
    final subtitles = <SimpleSubtitleLine>[];
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    bool inEventsSection = false;
    List<String>? formatFields;
    int startTimeIndex = -1;
    int endTimeIndex = -1;
    int textIndex = -1;
    int subtitleIndex = 1;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        inEventsSection = trimmed.toLowerCase() == '[events]';
        continue;
      }

      if (!inEventsSection || trimmed.isEmpty) {
        continue;
      }

      if (trimmed.toLowerCase().startsWith('format:')) {
        final declaration = trimmed.substring(trimmed.indexOf(':') + 1);
        formatFields = declaration.split(',').map((field) => field.trim()).toList();

        startTimeIndex = formatFields.indexWhere(
          (field) => field.toLowerCase() == 'start',
        );
        endTimeIndex = formatFields.indexWhere(
          (field) => field.toLowerCase() == 'end',
        );
        textIndex = formatFields.indexWhere(
          (field) => field.toLowerCase() == 'text',
        );
        continue;
      }

      if (!trimmed.toLowerCase().startsWith('dialogue:') ||
          formatFields == null ||
          startTimeIndex < 0 ||
          endTimeIndex < 0 ||
          textIndex < 0) {
        continue;
      }

      final payload = trimmed.substring(trimmed.indexOf(':') + 1).trimLeft();
      final fields = _splitAssLine(
        payload,
        fieldCount: formatFields.length,
        textIndex: textIndex,
      );

      if (fields.length != formatFields.length) {
        continue;
      }

      final startTime = _convertAssTime(fields[startTimeIndex]);
      final endTime = _convertAssTime(fields[endTimeIndex]);
      final text = fields[textIndex]
          .replaceAll(RegExp(r'\\N', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'\{[^}]*\}'), '');

      subtitles.add(
        SimpleSubtitleLine(
          index: subtitleIndex,
          startTime: startTime,
          endTime: endTime,
          text: text,
        ),
      );
      subtitleIndex++;
    }

    return subtitles;
  }

  /// Splits one ASS Dialogue payload according to the declared field count.
  ///
  /// Text is special because it may contain commas. Fields before Text are
  /// consumed from the left, while fields after Text are consumed from the
  /// right. This preserves commas inside Text even when Text is not the final
  /// declared field.
  static List<String> _splitAssLine(
    String line, {
    required int fieldCount,
    required int textIndex,
  }) {
    if (fieldCount <= 0 || textIndex < 0 || textIndex >= fieldCount) {
      return const [];
    }

    final prefix = <String>[];
    int textStart = 0;

    for (int i = 0; i < textIndex; i++) {
      final comma = line.indexOf(',', textStart);
      if (comma < 0) return const [];
      prefix.add(line.substring(textStart, comma).trim());
      textStart = comma + 1;
    }

    final suffix = <String>[];
    int textEnd = line.length;
    final suffixCount = fieldCount - textIndex - 1;

    for (int i = 0; i < suffixCount; i++) {
      final comma = line.lastIndexOf(',', textEnd - 1);
      if (comma < textStart) return const [];
      suffix.add(line.substring(comma + 1, textEnd).trim());
      textEnd = comma;
    }

    final text = line.substring(textStart, textEnd).trim();

    return [
      ...prefix,
      text,
      ...suffix.reversed,
    ];
  }

  // Convert ASS time format (h:mm:ss.cc) to standard format (hh:mm:ss.sss)
  static String _convertAssTime(String assTime) {
    final parts = assTime.split(':');
    if (parts.length == 3) {
      final hours = parts[0].padLeft(2, '0');
      final minutes = parts[1].padLeft(2, '0');
      final seconds = parts[2];
      
      // Convert centiseconds to milliseconds
      if (seconds.contains('.')) {
        final secondsParts = seconds.split('.');
        final secs = secondsParts[0].padLeft(2, '0');
        final cs = secondsParts[1];
        final ms = (int.parse(cs) * 10).toString().padLeft(3, '0');
        return '$hours:$minutes:$secs.$ms';
      }
      
      return '$hours:$minutes:$seconds.000';
    }
    return assTime;
  }
}
