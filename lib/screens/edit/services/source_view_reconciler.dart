import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/models/subtitle_entry.dart';

/// Reconciles editable Source View entries with persisted subtitle lines.
///
/// Source View exposes SRT cue numbers, timing and rendered text. Cue numbers
/// are used as identity hints only; persisted lines are always normalized back
/// to sequential indexes after reconciliation.
class SourceViewReconciler {
  const SourceViewReconciler._();

  static List<SubtitleLine> reconcile({
    required List<SubtitleLine> existingLines,
    required List<SubtitleEntry> entries,
  }) {
    final usedExisting = <int>{};
    final result = <SubtitleLine>[];

    for (int outputIndex = 0; outputIndex < entries.length; outputIndex++) {
      final entry = entries[outputIndex];
      final matchedIndex = _findExistingIndex(
        existingLines: existingLines,
        entry: entry,
        usedExisting: usedExisting,
      );

      final existing =
          matchedIndex == null ? null : existingLines[matchedIndex];

      if (matchedIndex != null) {
        usedExisting.add(matchedIndex);
      }

      result.add(
        _buildLine(
          entry: entry,
          sequentialIndex: outputIndex + 1,
          existing: existing,
        ),
      );
    }

    return result;
  }

  static int? _findExistingIndex({
    required List<SubtitleLine> existingLines,
    required SubtitleEntry entry,
    required Set<int> usedExisting,
  }) {
    final cueNumber = int.tryParse(entry.index.trim());

    if (cueNumber != null) {
      final candidateIndex = cueNumber - 1;
      if (candidateIndex >= 0 &&
          candidateIndex < existingLines.length &&
          !usedExisting.contains(candidateIndex)) {
        return candidateIndex;
      }
    }

    for (int i = 0; i < existingLines.length; i++) {
      if (usedExisting.contains(i)) continue;

      final line = existingLines[i];
      final renderedText = line.edited ?? line.original;
      if (line.startTime == entry.startTime &&
          line.endTime == entry.endTime &&
          renderedText == entry.text) {
        return i;
      }
    }

    return null;
  }

  static SubtitleLine _buildLine({
    required SubtitleEntry entry,
    required int sequentialIndex,
    SubtitleLine? existing,
  }) {
    if (existing == null) {
      return SubtitleLine()
        ..index = sequentialIndex
        ..startTime = entry.startTime
        ..endTime = entry.endTime
        ..original = entry.text
        ..edited = null
        ..marked = false
        ..comment = null
        ..resolved = false;
    }

    return SubtitleLine()
      ..index = sequentialIndex
      ..startTime = entry.startTime
      ..endTime = entry.endTime
      ..original = existing.original
      ..edited = entry.text == existing.original ? null : entry.text
      ..marked = existing.marked
      ..comment = existing.comment
      ..resolved = existing.resolved;
  }
}
