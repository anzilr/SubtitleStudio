import 'package:subtitle_studio/models/subtitle_entry.dart';

/// Lossless raw SRT editing boundary. Text stays a single editable document;
/// cue models are reconstructed only on Save, never during a partial keystroke.
abstract final class RawSrtDocument {
  static String compose(Iterable<SubtitleEntry> entries) =>
      entries.map((entry) =>
        '${entry.index}\n${entry.startTime} --> ${entry.endTime}\n${entry.text}'
      ).join('\n\n');

  /// Reject incomplete edits rather than silently saving the old cue list.
  /// Any number of valid cue blocks (including zero) is supported; an empty
  /// document is intentionally rejected to avoid accidental mass deletion.
  static List<SubtitleEntry> parseStrict(String text) {
    final normalized = text.replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) {
      throw const FormatException('Source is empty. Restore or add an SRT cue before saving.');
    }
    final blocks = normalized.split(RegExp(r'\n[ \t]*\n+'));
    final entries = <SubtitleEntry>[];
    for (var i = 0; i < blocks.length; i++) {
      final entry = SubtitleEntry.fromSrtText(blocks[i]);
      if (entry == null) {
        throw FormatException('Invalid SRT cue ${i + 1}: expected a cue number, time range and subtitle text.');
      }
      entries.add(entry);
    }
    return entries;
  }
}
