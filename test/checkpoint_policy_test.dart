import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_policy.dart';

Checkpoint _checkpoint({
  required int id,
  required String operationType,
  required String description,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 1,
    timestamp: DateTime.utc(2026, 1, 1, 0, 0, id),
    operationType: operationType,
    description: description,
    isActive: true,
    checkpointType: operationType == 'snapshot' ? 'snapshot' : 'delta',
    deltas: const [],
    snapshot: const [],
  )..id = id;
}

void main() {
  group('CheckpointPolicy.shouldCreateSnapshot', () {
    test('forceSnapshot always wins', () {
      expect(
        CheckpointPolicy.shouldCreateSnapshot(
          forceSnapshot: true,
          strategy: 'delta',
          checkpointsSinceSnapshot: 0,
          snapshotInterval: 10,
        ),
        isTrue,
      );
    });

    test('snapshot strategy always creates snapshots', () {
      expect(
        CheckpointPolicy.shouldCreateSnapshot(
          forceSnapshot: false,
          strategy: 'snapshot',
          checkpointsSinceSnapshot: 0,
          snapshotInterval: 10,
        ),
        isTrue,
      );
    });

    test('delta strategy never auto-creates snapshots', () {
      expect(
        CheckpointPolicy.shouldCreateSnapshot(
          forceSnapshot: false,
          strategy: 'delta',
          checkpointsSinceSnapshot: 50,
          snapshotInterval: 10,
        ),
        isFalse,
      );
    });

    test('hybrid creates snapshot at interval boundary', () {
      expect(
        CheckpointPolicy.shouldCreateSnapshot(
          forceSnapshot: false,
          strategy: 'hybrid',
          checkpointsSinceSnapshot: 10,
          snapshotInterval: 10,
        ),
        isTrue,
      );
      expect(
        CheckpointPolicy.shouldCreateSnapshot(
          forceSnapshot: false,
          strategy: 'hybrid',
          checkpointsSinceSnapshot: 9,
          snapshotInterval: 10,
        ),
        isFalse,
      );
    });
  });

  group('CheckpointPolicy.cleanupCandidates', () {
    test('unlimited checkpoint setting deletes nothing', () {
      final checkpoints = [
        _checkpoint(id: 3, operationType: 'edit', description: 'Edit 3'),
        _checkpoint(id: 2, operationType: 'edit', description: 'Edit 2'),
      ];

      expect(
        CheckpointPolicy.cleanupCandidates(
          checkpoints: checkpoints,
          maxCheckpoints: 0,
        ),
        isEmpty,
      );
    });

    test('selects only checkpoints older than the retention limit', () {
      final checkpoints = [
        _checkpoint(id: 4, operationType: 'edit', description: 'Edit 4'),
        _checkpoint(id: 3, operationType: 'edit', description: 'Edit 3'),
        _checkpoint(id: 2, operationType: 'edit', description: 'Edit 2'),
        _checkpoint(id: 1, operationType: 'edit', description: 'Edit 1'),
      ];

      final candidates = CheckpointPolicy.cleanupCandidates(
        checkpoints: checkpoints,
        maxCheckpoints: 2,
      );

      expect(candidates.map((c) => c.id), [2, 1]);
    });

    test('preserves manual and initial checkpoints past limit', () {
      final checkpoints = [
        _checkpoint(id: 5, operationType: 'edit', description: 'Edit 5'),
        _checkpoint(id: 4, operationType: 'edit', description: 'Edit 4'),
        _checkpoint(id: 3, operationType: 'manual', description: 'Keep me'),
        _checkpoint(
          id: 2,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
        _checkpoint(id: 1, operationType: 'edit', description: 'Old edit'),
      ];

      final candidates = CheckpointPolicy.cleanupCandidates(
        checkpoints: checkpoints,
        maxCheckpoints: 2,
      );

      expect(candidates.map((c) => c.id), [1]);
    });
  });
}
