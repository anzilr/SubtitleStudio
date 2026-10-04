import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_policy.dart';

Checkpoint _checkpoint({
  required int id,
  int? parentId,
  required String operationType,
  required String description,
  bool isActive = false,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 1,
    timestamp: DateTime.utc(2026, 1, 1, 0, 0, id),
    operationType: operationType,
    description: description,
    parentCheckpointId: parentId,
    isActive: isActive,
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
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Edit 2',
          isActive: true,
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      expect(
        CheckpointPolicy.cleanupCandidates(
          checkpoints: checkpoints,
          maxCheckpoints: 0,
          headCheckpointId: 2,
        ),
        isEmpty,
      );
    });

    test('never prunes current HEAD ancestry even when it exceeds limit', () {
      final checkpoints = [
        _checkpoint(
          id: 4,
          parentId: 3,
          operationType: 'edit',
          description: 'Edit 4',
          isActive: true,
        ),
        _checkpoint(
          id: 3,
          parentId: 2,
          operationType: 'edit',
          description: 'Edit 3',
        ),
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Edit 2',
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      expect(
        CheckpointPolicy.cleanupCandidates(
          checkpoints: checkpoints,
          maxCheckpoints: 2,
          headCheckpointId: 4,
        ),
        isEmpty,
      );
    });

    test('prunes an abandoned branch leaf before its parent', () {
      final checkpoints = [
        _checkpoint(
          id: 5,
          parentId: 4,
          operationType: 'edit',
          description: 'Current 5',
          isActive: true,
        ),
        _checkpoint(
          id: 4,
          parentId: 2,
          operationType: 'edit',
          description: 'Current 4',
        ),
        _checkpoint(
          id: 3,
          parentId: 2,
          operationType: 'edit',
          description: 'Abandoned 3',
        ),
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Edit 2',
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      final candidates = CheckpointPolicy.cleanupCandidates(
        checkpoints: checkpoints,
        maxCheckpoints: 4,
        headCheckpointId: 5,
        protectedAlternateBranchTips: 0,
      );

      expect(candidates.map((checkpoint) => checkpoint.id), [3]);
    });

    test('protects manual checkpoint ancestry on an alternate branch', () {
      final checkpoints = [
        _checkpoint(
          id: 6,
          parentId: 5,
          operationType: 'edit',
          description: 'Current 6',
          isActive: true,
        ),
        _checkpoint(
          id: 5,
          parentId: 2,
          operationType: 'edit',
          description: 'Current 5',
        ),
        _checkpoint(
          id: 4,
          parentId: 3,
          operationType: 'manual',
          description: 'Keep branch',
        ),
        _checkpoint(
          id: 3,
          parentId: 2,
          operationType: 'edit',
          description: 'Alternate 3',
        ),
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Edit 2',
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      expect(
        CheckpointPolicy.cleanupCandidates(
          checkpoints: checkpoints,
          maxCheckpoints: 3,
          headCheckpointId: 6,
        ),
        isEmpty,
      );
    });

    test('preserves a fresh alternate redo branch even above the limit', () {
      final checkpoints = [
        _checkpoint(
          id: 4,
          parentId: 2,
          operationType: 'edit',
          description: 'New branch',
          isActive: true,
        ),
        _checkpoint(
          id: 3,
          parentId: 2,
          operationType: 'edit',
          description: 'Previous branch',
        ),
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Fork point',
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      expect(
        CheckpointPolicy.cleanupCandidates(
          checkpoints: checkpoints,
          maxCheckpoints: 3,
          headCheckpointId: 4,
        ),
        isEmpty,
      );
    });

    test('prunes oldest alternate branch outside protected tip window', () {
      final checkpoints = [
        _checkpoint(
          id: 6,
          parentId: 5,
          operationType: 'edit',
          description: 'Current 6',
          isActive: true,
        ),
        _checkpoint(
          id: 5,
          parentId: 2,
          operationType: 'edit',
          description: 'Current 5',
        ),
        _checkpoint(
          id: 4,
          parentId: 2,
          operationType: 'edit',
          description: 'Recent alternate',
        ),
        _checkpoint(
          id: 3,
          parentId: 2,
          operationType: 'edit',
          description: 'Older alternate',
        ),
        _checkpoint(
          id: 2,
          parentId: 1,
          operationType: 'edit',
          description: 'Fork point',
        ),
        _checkpoint(
          id: 1,
          operationType: 'snapshot',
          description: 'Initial state',
        ),
      ];

      final candidates = CheckpointPolicy.cleanupCandidates(
        checkpoints: checkpoints,
        maxCheckpoints: 5,
        headCheckpointId: 6,
        protectedAlternateBranchTips: 1,
      );

      expect(candidates.map((checkpoint) => checkpoint.id), [3]);
    });
  });
}
