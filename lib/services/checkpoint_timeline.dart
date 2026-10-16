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
    final byId = {
      for (final checkpoint in checkpoints) checkpoint.id: checkpoint,
    };
    final visited = <int>{};
    int? currentId = targetCheckpointId;

    while (currentId != null) {
      if (!visited.add(currentId)) {
        return null;
      }

      final checkpoint = byId[currentId];
      if (checkpoint == null) return null;
      if (checkpoint.checkpointType == 'snapshot') return checkpoint;
      currentId = checkpoint.parentCheckpointId;
    }

    return null;
  }

  static int countSinceNearestSnapshot({
    required List<Checkpoint> checkpoints,
    required int? fromCheckpointId,
  }) {
    if (fromCheckpointId == null) return 0;

    final byId = {
      for (final checkpoint in checkpoints) checkpoint.id: checkpoint,
    };
    final visited = <int>{};
    var count = 0;
    int? currentId = fromCheckpointId;

    while (currentId != null) {
      if (!visited.add(currentId)) {
        return count;
      }

      final checkpoint = byId[currentId];
      if (checkpoint == null) {
        return count;
      }
      if (checkpoint.checkpointType == 'snapshot') {
        return count;
      }

      count++;
      currentId = checkpoint.parentCheckpointId;
    }

    return count;
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

    final visited = <int>{};
    while (currentId != null && currentId != fromSnapshotId) {
      if (!visited.add(currentId)) {
        throw StateError(
          'Checkpoint history contains a parent cycle at $currentId.',
        );
      }

      final checkpoint = byId[currentId];
      if (checkpoint == null) {
        throw StateError(
          'Checkpoint history is missing parent $currentId.',
        );
      }

      if (checkpoint.checkpointType == 'delta') {
        pathFromTarget.add(checkpoint);
      }

      currentId = checkpoint.parentCheckpointId;
    }

    if (currentId != fromSnapshotId) {
      throw StateError(
        'Checkpoint $toCheckpointId is not connected to snapshot '
        '$fromSnapshotId.',
      );
    }

    return pathFromTarget.reversed.toList();
  }

  static Set<int> ancestorPathIds({
    required List<Checkpoint> checkpoints,
    required int? fromCheckpointId,
  }) {
    final byId = {
      for (final checkpoint in checkpoints) checkpoint.id: checkpoint,
    };
    final ancestors = <int>{};

    int? currentId = fromCheckpointId;
    while (currentId != null && ancestors.add(currentId)) {
      currentId = byId[currentId]?.parentCheckpointId;
    }

    return ancestors;
  }

  static List<Checkpoint> childrenOf({
    required List<Checkpoint> checkpoints,
    required int parentCheckpointId,
  }) {
    final children = checkpoints
        .where(
          (checkpoint) =>
              checkpoint.parentCheckpointId == parentCheckpointId,
        )
        .toList();
    children.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return children;
  }

  static Set<int> protectedAncestryIds({
    required List<Checkpoint> checkpoints,
    required int? headCheckpointId,
    bool protectManualCheckpoints = true,
  }) {
    final protectedIds = ancestorPathIds(
      checkpoints: checkpoints,
      fromCheckpointId: headCheckpointId,
    );

    if (protectManualCheckpoints) {
      for (final checkpoint in checkpoints) {
        if (checkpoint.operationType != 'manual') continue;
        protectedIds.addAll(
          ancestorPathIds(
            checkpoints: checkpoints,
            fromCheckpointId: checkpoint.id,
          ),
        );
      }
    }

    for (final checkpoint in checkpoints) {
      if (checkpoint.operationType == 'snapshot' &&
          checkpoint.description == 'Initial state') {
        protectedIds.add(checkpoint.id);
      }
    }

    return protectedIds;
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
