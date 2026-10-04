import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
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
    _verifyStateHash(
      checkpoint: nearestSnapshot,
      lines: restored,
      label: 'snapshot',
    );

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
        final expectedParentHash =
            CheckpointHistoryMetadata.parentStateHash(checkpoint);
        if (expectedParentHash != null) {
          final actualParentHash =
              CheckpointStateHasher.hashLines(restored);
          if (actualParentHash != expectedParentHash) {
            throw CheckpointIntegrityException(
              'Checkpoint \${checkpoint.id} parent-state hash mismatch.',
            );
          }
        }

        CheckpointStateReducer.applyDeltasStrictInPlace(
          restored,
          checkpoint.deltas,
        );
        _verifyStateHash(
          checkpoint: checkpoint,
          lines: restored,
          label: 'commit',
        );
      }
    }

    return restored;
  }

  static void _verifyStateHash({
    required Checkpoint checkpoint,
    required List<SubtitleLine> lines,
    required String label,
  }) {
    final expected = CheckpointHistoryMetadata.stateHash(checkpoint);
    if (expected == null) return;

    final actual = CheckpointStateHasher.hashLines(lines);
    if (actual != expected) {
      throw CheckpointIntegrityException(
        'Checkpoint \${checkpoint.id} $label state hash mismatch.',
      );
    }
  }
}
