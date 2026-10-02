import 'package:subtitle_studio/database/models/models.dart';

/// Pure checkpoint-tree traversal helpers.
///
/// Callers are responsible for providing checkpoints from a single session.
class CheckpointTimeline {
  const CheckpointTimeline._();

  static int countSinceLastSnapshot(List<Checkpoint> newestFirst) {
    Checkpoint? lastSnapshot;
    for (final checkpoint in newestFirst) {
      if (checkpoint.checkpointType == 'snapshot') {
        lastSnapshot = checkpoint;
        break;
      }
    }

    if (lastSnapshot == null) return newestFirst.length;

    var count = 0;
    for (final checkpoint in newestFirst) {
      if (checkpoint.timestamp.isAfter(lastSnapshot.timestamp)) {
        count++;
      }
    }
    return count;
  }

  static Checkpoint? findNearestSnapshot({
    required List<Checkpoint> checkpoints,
    required int targetCheckpointId,
  }) {
    final byId = {for (final checkpoint in checkpoints) checkpoint.id: checkpoint};
    int? currentId = targetCheckpointId;

    while (currentId != null) {
      final checkpoint = byId[currentId];
      if (checkpoint == null) return null;
      if (checkpoint.checkpointType == 'snapshot') return checkpoint;
      currentId = checkpoint.parentCheckpointId;
    }

    return null;
  }

  static List<Checkpoint> deltaPath({
    required List<Checkpoint> checkpoints,
    required int fromSnapshotId,
    required int toCheckpointId,
    bool excludeTarget = false,
  }) {
    if (fromSnapshotId == toCheckpointId) return const <Checkpoint>[];

    final byId = {for (final checkpoint in checkpoints) checkpoint.id: checkpoint};
    final pathFromTarget = <Checkpoint>[];

    int? currentId = toCheckpointId;
    if (excludeTarget) {
      currentId = byId[toCheckpointId]?.parentCheckpointId;
    }

    while (currentId != null && currentId != fromSnapshotId) {
      final checkpoint = byId[currentId];
      if (checkpoint == null) break;

      if (checkpoint.checkpointType == 'delta') {
        pathFromTarget.add(checkpoint);
      }

      currentId = checkpoint.parentCheckpointId;
    }

    return pathFromTarget.reversed.toList();
  }

  static Set<int> descendantIds({
    required List<Checkpoint> checkpoints,
    required int parentCheckpointId,
  }) {
    final childrenByParent = <int, List<int>>{};
    for (final checkpoint in checkpoints) {
      final parentId = checkpoint.parentCheckpointId;
      if (parentId == null) continue;
      childrenByParent.putIfAbsent(parentId, () => <int>[]).add(checkpoint.id);
    }

    final descendants = <int>{};
    final pending = <int>[parentCheckpointId];

    while (pending.isNotEmpty) {
      final parentId = pending.removeLast();
      for (final childId in childrenByParent[parentId] ?? const <int>[]) {
        if (descendants.add(childId)) {
          pending.add(childId);
        }
      }
    }

    return descendants;
  }
}
