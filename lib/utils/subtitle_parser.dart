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
    List<SimpleSubtitleLine> subtitles = [];
    
    // Normalize line endings and split into blocks
    final normalizedContent = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalizedContent.split('\n\n').where((block) => block.trim().isNotEmpty).toList();
    
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue; // Need at least index, timestamp, and text
      
      // Parse index
      final indexMatch = RegExp(r'^\d+$').firstMatch(lines[0]);
      if (indexMatch == null) continue;
      final index = int.parse(lines[0]);
      
      // Parse timestamp
      final timeMatch = RegExp(r'(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})').firstMatch(lines[1]);
      if (timeMatch == null) continue;
      final startTime = timeMatch.group(1)!.replaceAll(',', '.');
      final endTime = timeMatch.group(2)!.replaceAll(',', '.');
      
      // Join remaining lines as text (preserving newlines)
      final text = lines.skip(2).join('\n');
      
      subtitles.add(SimpleSubtitleLine(
        index: index,
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
    }
    
    return subtitles;
  }
  
  // Parse VTT format
  static List<SimpleSubtitleLine> parseVtt(String content) {
    List<SimpleSubtitleLine> subtitles = [];
    
    // Skip the WEBVTT header
    final contentWithoutHeader = content.replaceFirst(RegExp(r'WEBVTT.*?\n\n', dotAll: true), '');
    
    // Normalize line endings and split into blocks
    final normalizedContent = contentWithoutHeader.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalizedContent.split('\n\n').where((block) => block.trim().isNotEmpty).toList();
    
    int index = 1;
    
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue; // Need at least timestamp and text
      
      int timestampLineIndex = 0;
      
      // Check if first line is an index
      if (RegExp(r'^\d+$').hasMatch(lines[0])) {
        index = int.parse(lines[0]);
        timestampLineIndex = 1;
      }
      
      if (timestampLineIndex >= lines.length) continue;
      
      // Parse timestamp
      final timeMatch = RegExp(r'(\d{2}:\d{2}:\d{2}\.\d{3}) --> (\d{2}:\d{2}:\d{2}\.\d{3})').firstMatch(lines[timestampLineIndex]);
      if (timeMatch == null) continue;
      final startTime = timeMatch.group(1)!;
      final endTime = timeMatch.group(2)!;
      
      // Join remaining lines as text (preserving newlines)
      final textLines = lines.skip(timestampLineIndex + 1).toList();
      final text = textLines.join('\n')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n') // Convert <br> tags to newlines
        .replaceAll(RegExp(r'<(?!br)[^>]*>'), ''); // Remove other HTML tags but preserve <br>
      
      subtitles.add(SimpleSubtitleLine(
        index: index,
        startTime: startTime,
        endTime: endTime,
        text: text,
      ));
      
      index++;
    }
    
    return subtitles;
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
        startTime = _convertAssTime(startTime);
        endTime = _convertAssTime(endTime);
        
        subtitles.add(SimpleSubtitleLine(
          index: index,
          startTime: startTime,
          endTime: endTime,
          text: text,
        ));
        
        index++;
      }
    }
    
    return subtitles;
  }
  
  // Helper method to handle ASS line splitting correctly (respecting commas in text)
  static List<String> _splitAssLine(String line) {
    List<String> result = [];
    bool inQuote = false;
    int lastSplit = 0;
    
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ',') {
        if (!inQuote) {
          result.add(line.substring(lastSplit, i).trim());
          lastSplit = i + 1;
        }
      }
      // Handle text field which might contain commas
      if (result.length == 9) {
        result.add(line.substring(lastSplit).trim());
        break;
      }
    }
    
    return result;
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
