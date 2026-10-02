import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_sorting.dart';

/// Pure subtitle-state operations used by checkpoint reconstruction.
///
/// Persistence, checkpoint-tree traversal, and preference policy intentionally
/// remain outside this class. Keeping these transforms isolated makes restore
/// behavior testable without opening Isar.
class CheckpointStateReducer {
  const CheckpointStateReducer._();

  static SubtitleLine copyLine(SubtitleLine line) {
    return SubtitleLine()
      ..index = line.index
      ..startTime = line.startTime
      ..endTime = line.endTime
      ..original = line.original
      ..edited = line.edited
      ..marked = line.marked
      ..comment = line.comment
      ..resolved = line.resolved;
  }

  static List<SubtitleLine> copyLines(Iterable<SubtitleLine> lines) {
    return lines.map(copyLine).toList(growable: true);
  }

  /// Applies checkpoint deltas in chronological order.
  ///
  /// The input list is mutated in place to preserve the existing
  /// CheckpointManager reconstruction semantics.
  static void applyDeltasInPlace(
    List<SubtitleLine> lines,
    List<SubtitleLineDelta> deltas,
  ) {
    for (final delta in deltas) {
      switch (delta.changeType) {
        case 'add':
          final afterState = delta.afterState;
          if (afterState != null) {
            final insertIndex = delta.lineIndex.clamp(0, lines.length);
            lines.insert(insertIndex, copyLine(afterState));
          }
          break;
        case 'delete':
          if (delta.lineIndex >= 0 && delta.lineIndex < lines.length) {
            lines.removeAt(delta.lineIndex);
          }
          break;
        case 'modify':
          final afterState = delta.afterState;
          if (afterState != null &&
              delta.lineIndex >= 0 &&
              delta.lineIndex < lines.length) {
            lines[delta.lineIndex] = copyLine(afterState);
          }
          break;
      }
    }
  }

  static void reindexCollection(SubtitleCollection collection) {
    collection.lines = sortAndReindexSubtitleLines(collection.lines);
  }
}
