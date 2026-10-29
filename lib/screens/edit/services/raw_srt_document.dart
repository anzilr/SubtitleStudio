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
        .replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) {
      throw const FormatException('The subtitle source is empty. Add a subtitle line before saving.');
    }
    // A blank line in subtitle text is not automatically a cue separator.
    // Split only when the following text looks like a *numbered cue header*.
    // This keeps interior blank lines and completely empty cues intact.
    final withoutLeadingSeparators = normalized.replaceFirst(
      RegExp(r'^(?:[ \t]*\n)+'), '',
    );
    final blocks = withoutLeadingSeparators.split(RegExp(
      r'\n[ \t]*\n(?=[ \t]*\d+[ \t]*\n[^\n]*-->)',
    ));
    final entries = <SubtitleEntry>[];
    for (var i = 0; i < blocks.length; i++) {
      final entry = SubtitleEntry.fromSrtText(blocks[i]);
      if (entry == null) {
        throw FormatException('Invalid subtitle line ${i + 1}: expected a line number and time range.');
      }
      entries.add(entry);
    }
    return entries;
  }
}
