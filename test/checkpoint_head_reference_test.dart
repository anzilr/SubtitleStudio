import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

Checkpoint _checkpoint({
  required int id,
  required DateTime timestamp,
  int? parentId,
  bool isActive = false,
  bool v2 = false,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 1,
    timestamp: timestamp,
    operationType: v2 ? 'edit' : 'legacy',
    description: 'Checkpoint $id',
    parentCheckpointId: parentId,
    isActive: isActive,
    checkpointType: 'snapshot',
    deltas: const [],
    snapshot: const [],
    metadata: v2
        ? CheckpointHistoryMetadata.encodePostOperation()
        : null,
  )..id = id;
}

void main() {
  group('CheckpointHeadReference', () {
    test('legacy active path resolves newest active checkpoint', () {
      final checkpoints = [
        _checkpoint(
          id: 1,
          timestamp: DateTime.utc(2026, 10, 4, 10),
          isActive: true,
        ),
        _checkpoint(
          id: 2,
          timestamp: DateTime.utc(2026, 10, 4, 11),
          parentId: 1,
          isActive: true,
        ),
      ];

      expect(
        CheckpointHeadReference.resolveForMutation(checkpoints)?.id,
        2,
      );
    });

    test('mixed history allows one legacy checkpoint as HEAD', () {
      final legacyHead = _checkpoint(
        id: 1,
        timestamp: DateTime.utc(2026, 10, 4, 10),
        isActive: true,
      );
      final v2Descendant = _checkpoint(
        id: 2,
        timestamp: DateTime.utc(2026, 10, 4, 11),
        parentId: 1,
        v2: true,
      );

      expect(
        CheckpointHeadReference.resolveForMutation(
          [legacyHead, v2Descendant],
        )?.id,
        1,
      );
    });

    test('v2 history rejects multiple active HEAD markers', () {
      final first = _checkpoint(
        id: 1,
        timestamp: DateTime.utc(2026, 10, 4, 10),
        isActive: true,
        v2: true,
      );
      final second = _checkpoint(
        id: 2,
        timestamp: DateTime.utc(2026, 10, 4, 11),
        parentId: 1,
        isActive: true,
        v2: true,
      );

      expect(
        () => CheckpointHeadReference.resolveForMutation([first, second]),
        throwsA(isA<CheckpointIntegrityException>()),
      );
    });

    test('moveInMemory produces exactly one active HEAD', () {
      final checkpoints = [
        _checkpoint(
          id: 1,
          timestamp: DateTime.utc(2026, 10, 4, 10),
          isActive: true,
        ),
        _checkpoint(
          id: 2,
          timestamp: DateTime.utc(2026, 10, 4, 11),
          parentId: 1,
        ),
        _checkpoint(
          id: 3,
          timestamp: DateTime.utc(2026, 10, 4, 12),
          parentId: 2,
          isActive: true,
        ),
      ];

      CheckpointHeadReference.moveInMemory(
        checkpoints: checkpoints,
        checkpointId: 2,
      );

      expect(
        checkpoints.where((checkpoint) => checkpoint.isActive).map((c) => c.id),
        [2],
      );
    });
  });
}
