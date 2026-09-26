import 'package:subtitle_studio/database/models/models.dart';

/// Represents one editable subtitle entry in source/SRT form.
///
/// This model is intentionally independent of the Editor UI so repositories
/// and Riverpod controllers do not need to import the large screen widget.
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

  static SubtitleEntry? fromSrtText(String srtText) {
    final lines = srtText.trim().split('\n');
    if (lines.length < 3) return null;

    final index = lines[0].trim();
    final timecode = lines[1].trim();
    final text = lines.skip(2).join('\n').trim();

    final timeParts = timecode.split(' --> ');
    if (timeParts.length != 2) return null;

    return SubtitleEntry(
      index: index,
      startTime: timeParts[0].trim(),
      endTime: timeParts[1].trim(),
      text: text,
    );
  }

  static SubtitleEntry fromSubtitleLine(SubtitleLine line, int index) {
    return SubtitleEntry(
      index: (index + 1).toString(),
      startTime: line.startTime,
      endTime: line.endTime,
      text: line.edited ?? line.original,
    );
  }
}
