import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// History-aware edits to annotation fields on a single subtitle line.
///
/// Mark, comment and resolution changes are genuine document mutations. They
/// must be committed with the subtitle state, not written in a separate txn.
/// [lineIndex] is a zero-based collection position, not a cue number.
class CheckpointLineMetadataService {
  final CheckpointHistoryTransaction _history;

  CheckpointLineMetadataService(Isar isar)
      : _history = CheckpointHistoryTransaction(isar);

  Future<bool> change({
    required int sessionId,
    required int collectionId,
    required int lineIndex,
    required String description,
    required void Function(SubtitleLine line) modify,
  }) async {
    await _history.commit(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
      operationType: 'annotation',
      description: description,
      buildMutation: (currentLines) {
        if (lineIndex < 0 || lineIndex >= currentLines.length) {
          throw RangeError.index(lineIndex, currentLines, 'lineIndex');
        }

        final next = CheckpointStateReducer.copyLines(currentLines);
        final before = CheckpointStateReducer.copyLine(next[lineIndex]);
        modify(next[lineIndex]);

        if (CheckpointStateReducer.samePersistedLine(before, next[lineIndex])) {
          return CheckpointMutationPlan(
            nextLines: next,
            deltas: const <SubtitleLineDelta>[],
          );
        }

        return CheckpointMutationPlan(
          nextLines: next,
          deltas: [
            SubtitleLineDelta()
              ..changeType = 'modify'
              ..lineIndex = lineIndex
              ..beforeState = before
              ..afterState = CheckpointStateReducer.copyLine(next[lineIndex]),
          ],
        );
      },
    );
    return true;
  }
}
