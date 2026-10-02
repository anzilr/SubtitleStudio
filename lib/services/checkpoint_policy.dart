import 'package:subtitle_studio/database/models/models.dart';

/// Pure policy decisions for checkpoint creation and retention.
///
/// Database access and preference loading remain outside this class.
class CheckpointPolicy {
  const CheckpointPolicy._();

  static bool shouldCreateSnapshot({
    required bool forceSnapshot,
    required String strategy,
    required int checkpointsSinceSnapshot,
    required int snapshotInterval,
  }) {
    if (forceSnapshot) return true;

    switch (strategy) {
      case 'snapshot':
        return true;
      case 'delta':
        return false;
      default:
        return checkpointsSinceSnapshot >= snapshotInterval;
    }
  }

  /// Returns old checkpoints eligible for deletion.
  ///
  /// [checkpoints] must be ordered newest-first, matching
  /// CheckpointManager.getCheckpointsForSession.
  static List<Checkpoint> cleanupCandidates({
    required List<Checkpoint> checkpoints,
    required int maxCheckpoints,
  }) {
    if (maxCheckpoints <= 0 || checkpoints.length <= maxCheckpoints) {
      return const <Checkpoint>[];
    }

    return checkpoints
        .skip(maxCheckpoints)
        .where(
          (checkpoint) =>
              checkpoint.operationType != 'manual' &&
              !(checkpoint.operationType == 'snapshot' &&
                  checkpoint.description == 'Initial state'),
        )
        .toList();
  }
}
