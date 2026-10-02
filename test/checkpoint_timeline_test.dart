import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';

Checkpoint _checkpoint({
  required int id,
  int? parentId,
  required String type,
  required int second,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 1,
    timestamp: DateTime.utc(2026, 1, 1, 0, 0, second),
    operationType: type == 'snapshot' ? 'snapshot' : 'edit',
    description: 'CP $id',
    parentCheckpointId: parentId,
    isActive: true,
    checkpointType: type,
    deltas: const [],
    snapshot: const [],
  )..id = id;
}

void main() {
  group('CheckpointTimeline', () {
    test('counts checkpoints newer than most recent snapshot', () {
      final checkpoints = [
        _checkpoint(id: 4, parentId: 3, type: 'delta', second: 4),
        _checkpoint(id: 3, parentId: 2, type: 'delta', second: 3),
        _checkpoint(id: 2, parentId: 1, type: 'snapshot', second: 2),
        _checkpoint(id: 1, type: 'snapshot', second: 1),
      ];

      expect(CheckpointTimeline.countSinceLastSnapshot(checkpoints), 2);
    });

    test('uses total count when there is no snapshot', () {
      final checkpoints = [
        _checkpoint(id: 2, parentId: 1, type: 'delta', second: 2),
        _checkpoint(id: 1, type: 'delta', second: 1),
      ];

      expect(CheckpointTimeline.countSinceLastSnapshot(checkpoints), 2);
    });

    test('finds nearest snapshot through parent chain', () {
      final root = _checkpoint(id: 1, type: 'snapshot', second: 1);
      final laterSnapshot = _checkpoint(
        id: 3,
        parentId: 2,
        type: 'snapshot',
        second: 3,
      );
      final checkpoints = [
        _checkpoint(id: 4, parentId: 3, type: 'delta', second: 4),
        laterSnapshot,
        _checkpoint(id: 2, parentId: 1, type: 'delta', second: 2),
        root,
      ];

      expect(
        CheckpointTimeline.findNearestSnapshot(
          checkpoints: checkpoints,
          targetCheckpointId: 4,
        )?.id,
        3,
      );
    });

    test('returns null when parent chain is incomplete', () {
      final checkpoints = [
        _checkpoint(id: 4, parentId: 99, type: 'delta', second: 4),
      ];

      expect(
        CheckpointTimeline.findNearestSnapshot(
          checkpoints: checkpoints,
          targetCheckpointId: 4,
        ),
        isNull,
      );
    });

    test('builds chronological delta path and can exclude target', () {
      final checkpoints = [
        _checkpoint(id: 4, parentId: 3, type: 'delta', second: 4),
        _checkpoint(id: 3, parentId: 2, type: 'delta', second: 3),
        _checkpoint(id: 2, parentId: 1, type: 'delta', second: 2),
        _checkpoint(id: 1, type: 'snapshot', second: 1),
      ];

      expect(
        CheckpointTimeline.deltaPath(
          checkpoints: checkpoints,
          fromSnapshotId: 1,
          toCheckpointId: 4,
        ).map((c) => c.id),
        [2, 3, 4],
      );

      expect(
        CheckpointTimeline.deltaPath(
          checkpoints: checkpoints,
          fromSnapshotId: 1,
          toCheckpointId: 4,
          excludeTarget: true,
        ).map((c) => c.id),
        [2, 3],
      );
    });

    test('collects all descendants across branches', () {
      final checkpoints = [
        _checkpoint(id: 1, type: 'snapshot', second: 1),
        _checkpoint(id: 2, parentId: 1, type: 'delta', second: 2),
        _checkpoint(id: 3, parentId: 2, type: 'delta', second: 3),
        _checkpoint(id: 4, parentId: 2, type: 'delta', second: 4),
        _checkpoint(id: 5, parentId: 4, type: 'delta', second: 5),
      ];

      expect(
        CheckpointTimeline.descendantIds(
          checkpoints: checkpoints,
          parentCheckpointId: 2,
        ),
        {3, 4, 5},
      );
    });
  });
}
