import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';

/// Pure reconstruction for v2 Git-style checkpoint commits.
///
/// A v2 checkpoint represents the state AFTER its operation. Reconstruction
/// starts from the nearest v2 snapshot and replays strict deltas along the
/// target's parent chain. Invalid graphs or deltas fail closed.
class CheckpointReconstructor {
  const CheckpointReconstructor._();

  static List<SubtitleLine> reconstructPostOperation({
    required List<Checkpoint> checkpoints,
    required int targetCheckpointId,
  }) {
    final byId = {
      for (final checkpoint in checkpoints) checkpoint.id: checkpoint,
    };
    final target = byId[targetCheckpointId];
    if (target == null) {
      throw StateError('Checkpoint $targetCheckpointId was not found.');
    }
    if (!CheckpointHistoryMetadata.isPostOperation(target)) {
      throw StateError(
        'Checkpoint $targetCheckpointId does not use v2 '
        'post-operation semantics.',
      );
    }

    final nearestSnapshot = CheckpointTimeline.findNearestSnapshot(
      checkpoints: checkpoints,
      targetCheckpointId: targetCheckpointId,
    );
    if (nearestSnapshot == null ||
        nearestSnapshot.snapshot.isEmpty ||
        !CheckpointHistoryMetadata.isPostOperation(nearestSnapshot)) {
      throw StateError(
        'Checkpoint $targetCheckpointId has no compatible v2 snapshot '
        'ancestor.',
      );
    }

    final restored =
        CheckpointStateReducer.copyLines(nearestSnapshot.snapshot);

    if (nearestSnapshot.id != targetCheckpointId) {
      final path = CheckpointTimeline.deltaPath(
        checkpoints: checkpoints,
        fromSnapshotId: nearestSnapshot.id,
        toCheckpointId: targetCheckpointId,
        excludeTarget: false,
      );

      for (final checkpoint in path) {
        if (!CheckpointHistoryMetadata.isPostOperation(checkpoint)) {
          throw StateError(
            'Checkpoint ${checkpoint.id} crosses into legacy '
            'pre-operation history without a v2 snapshot boundary.',
          );
        }
        CheckpointStateReducer.applyDeltasStrictInPlace(
          restored,
          checkpoint.deltas,
        );
      }
    }

    return restored;
  }
}
