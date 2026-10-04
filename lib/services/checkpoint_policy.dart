import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';

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

  /// Returns checkpoints that can be safely pruned without breaking any
  /// retained parent chain.
  ///
  /// The current HEAD ancestry, every manual checkpoint ancestry, the initial
  /// snapshot, and a small number of recent alternate branch tips are
  /// protected. Cleanup removes only unprotected leaves, oldest first, so it
  /// can never retain a child whose parent was deleted.
  ///
  /// If the protected graph itself exceeds [maxCheckpoints], no protected
  /// checkpoint is deleted and the configured limit is intentionally exceeded.
  static List<Checkpoint> cleanupCandidates({
    required List<Checkpoint> checkpoints,
    required int maxCheckpoints,
    int? headCheckpointId,
    int protectedAlternateBranchTips = 2,
  }) {
    if (maxCheckpoints <= 0 || checkpoints.length <= maxCheckpoints) {
      return const <Checkpoint>[];
    }

    final resolvedHeadId = headCheckpointId ??
        CheckpointHeadReference.newestActive(checkpoints)?.id;

    final protectedIds = CheckpointTimeline.protectedAncestryIds(
      checkpoints: checkpoints,
      headCheckpointId: resolvedHeadId,
    );

    if (protectedAlternateBranchTips > 0) {
      final parentIds = <int>{
        for (final checkpoint in checkpoints)
          if (checkpoint.parentCheckpointId != null)
            checkpoint.parentCheckpointId!,
      };

      final alternateTips = checkpoints
          .where(
            (checkpoint) =>
                !parentIds.contains(checkpoint.id) &&
                !protectedIds.contains(checkpoint.id),
          )
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      for (final tip in alternateTips.take(protectedAlternateBranchTips)) {
        protectedIds.addAll(
          CheckpointTimeline.ancestorPathIds(
            checkpoints: checkpoints,
            fromCheckpointId: tip.id,
          ),
        );
      }
    }

    final remainingById = {
      for (final checkpoint in checkpoints) checkpoint.id: checkpoint,
    };
    final deleted = <Checkpoint>[];

    while (remainingById.length > maxCheckpoints) {
      final parentIdsWithChildren = <int>{};
      for (final checkpoint in remainingById.values) {
        final parentId = checkpoint.parentCheckpointId;
        if (parentId != null && remainingById.containsKey(parentId)) {
          parentIdsWithChildren.add(parentId);
        }
      }

      final removableLeaves = remainingById.values
          .where(
            (checkpoint) =>
                !protectedIds.contains(checkpoint.id) &&
                !parentIdsWithChildren.contains(checkpoint.id),
          )
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (removableLeaves.isEmpty) {
        break;
      }

      final candidate = removableLeaves.first;
      remainingById.remove(candidate.id);
      deleted.add(candidate);
    }

    return deleted;
  }
}
