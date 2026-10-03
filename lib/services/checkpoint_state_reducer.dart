import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/subtitle_sorting.dart';

/// Pure subtitle-state operations used by checkpoint reconstruction.
///
/// Persistence, checkpoint-tree traversal, and preference policy intentionally
/// remain outside this class. Keeping these transforms isolated makes restore
/// behavior testable without opening Isar.
class CheckpointIntegrityException implements Exception {
  final String message;

  const CheckpointIntegrityException(this.message);

  @override
  String toString() => 'CheckpointIntegrityException: $message';
}

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

  static void applyDeltasStrictInPlace(
    List<SubtitleLine> lines,
    List<SubtitleLineDelta> deltas,
  ) {
    for (final delta in deltas) {
      switch (delta.changeType) {
        case 'add':
          final afterState = delta.afterState;
          if (afterState == null) {
            throw const CheckpointIntegrityException(
              'Add delta is missing afterState.',
            );
          }
          if (delta.lineIndex < 0 || delta.lineIndex > lines.length) {
            throw CheckpointIntegrityException(
              'Add delta index ${delta.lineIndex} is outside '
              '0..${lines.length}.',
            );
          }
          lines.insert(delta.lineIndex, copyLine(afterState));
          break;

        case 'delete':
          final beforeState = delta.beforeState;
          if (beforeState == null) {
            throw const CheckpointIntegrityException(
              'Delete delta is missing beforeState.',
            );
          }
          if (delta.lineIndex < 0 || delta.lineIndex >= lines.length) {
            throw CheckpointIntegrityException(
              'Delete delta index ${delta.lineIndex} is outside '
              '0..${lines.length - 1}.',
            );
          }
          if (!_samePersistedLine(lines[delta.lineIndex], beforeState)) {
            throw CheckpointIntegrityException(
              'Delete delta does not match the reconstructed line at '
              'index ${delta.lineIndex}.',
            );
          }
          lines.removeAt(delta.lineIndex);
          break;

        case 'modify':
          final beforeState = delta.beforeState;
          final afterState = delta.afterState;
          if (beforeState == null || afterState == null) {
            throw const CheckpointIntegrityException(
              'Modify delta requires both beforeState and afterState.',
            );
          }
          if (delta.lineIndex < 0 || delta.lineIndex >= lines.length) {
            throw CheckpointIntegrityException(
              'Modify delta index ${delta.lineIndex} is outside '
              '0..${lines.length - 1}.',
            );
          }
          if (!_samePersistedLine(lines[delta.lineIndex], beforeState)) {
            throw CheckpointIntegrityException(
              'Modify delta does not match the reconstructed line at '
              'index ${delta.lineIndex}.',
            );
          }
          lines[delta.lineIndex] = copyLine(afterState);
          break;

        default:
          throw CheckpointIntegrityException(
            'Unknown delta type: ${delta.changeType}.',
          );
      }
    }
  }

  static bool _samePersistedLine(
    SubtitleLine left,
    SubtitleLine right,
  ) {
    return left.index == right.index &&
        left.startTime == right.startTime &&
        left.endTime == right.endTime &&
        left.original == right.original &&
        left.edited == right.edited &&
        left.marked == right.marked &&
        left.comment == right.comment &&
        left.resolved == right.resolved;
  }

  /// Reindexes lines without changing their stored order.
  ///
  /// History restoration must reproduce the exact checkpoint ordering rather
  /// than applying the editor's normal time-based sorting policy.
  static void reindexExactOrder(SubtitleCollection collection) {
    for (var i = 0; i < collection.lines.length; i++) {
      collection.lines[i].index = i + 1;
    }
  }

  static void reindexCollection(SubtitleCollection collection) {
    collection.lines = sortAndReindexSubtitleLines(collection.lines);
  }
}
