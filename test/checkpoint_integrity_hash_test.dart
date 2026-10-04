import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_reconstructor.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

SubtitleLine _line(int index, String text) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

Checkpoint _snapshot({
  required int id,
  required List<SubtitleLine> lines,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 1,
    timestamp: DateTime.utc(2026, 10, 4, 12),
    operationType: 'snapshot',
    description: 'Snapshot',
    parentCheckpointId: null,
    isActive: false,
    checkpointType: 'snapshot',
    deltas: const [],
    snapshot: CheckpointStateReducer.copyLines(lines),
    metadata: CheckpointHistoryMetadata.encodePostOperation(
      stateHash: CheckpointStateHasher.hashLines(lines),
    ),
  )..id = id;
}

void main() {
  group('Checkpoint state integrity hashes', () {
    test('valid hashed snapshot reconstructs normally', () {
      final lines = [_line(1, 'A'), _line(2, 'B')];
      final root = _snapshot(id: 1, lines: lines);

      final restored = CheckpointReconstructor.reconstructPostOperation(
        checkpoints: [root],
        targetCheckpointId: root.id,
      );

      expect(restored.map((line) => line.original).toList(), ['A', 'B']);
      expect(
        CheckpointHistoryMetadata.stateHash(root),
        CheckpointStateHasher.hashLines(restored),
      );
    });

    test('tampered snapshot is rejected', () {
      final root = _snapshot(
        id: 1,
        lines: [_line(1, 'Original')],
      );

      root.snapshot.first.original = 'Tampered';

      expect(
        () => CheckpointReconstructor.reconstructPostOperation(
          checkpoints: [root],
          targetCheckpointId: root.id,
        ),
        throwsA(isA<CheckpointIntegrityException>()),
      );
    });

    test('tampered delta result is rejected', () {
      final before = [_line(1, 'A')];
      final after = [_line(1, 'B')];
      final root = _snapshot(id: 1, lines: before);

      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..beforeState = _line(1, 'A')
        ..afterState = _line(1, 'B');

      final commit = Checkpoint(
        sessionId: 1,
        subtitleCollectionId: 1,
        timestamp: DateTime.utc(2026, 10, 4, 13),
        operationType: 'edit',
        description: 'Edit',
        parentCheckpointId: root.id,
        isActive: true,
        checkpointType: 'delta',
        deltas: [delta],
        snapshot: const [],
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          parentStateHash: CheckpointStateHasher.hashLines(before),
          stateHash: CheckpointStateHasher.hashLines(after),
        ),
      )..id = 2;

      commit.deltas.single.afterState!.original = 'Tampered';

      expect(
        () => CheckpointReconstructor.reconstructPostOperation(
          checkpoints: [root, commit],
          targetCheckpointId: commit.id,
        ),
        throwsA(isA<CheckpointIntegrityException>()),
      );
    });

    test('parent-state hash mismatch is rejected before replay', () {
      final before = [_line(1, 'A')];
      final root = _snapshot(id: 1, lines: before);

      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..beforeState = _line(1, 'A')
        ..afterState = _line(1, 'B');

      final commit = Checkpoint(
        sessionId: 1,
        subtitleCollectionId: 1,
        timestamp: DateTime.utc(2026, 10, 4, 13),
        operationType: 'edit',
        description: 'Edit',
        parentCheckpointId: root.id,
        isActive: true,
        checkpointType: 'delta',
        deltas: [delta],
        snapshot: const [],
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          parentStateHash: CheckpointStateHasher.hashLines(
            [_line(1, 'Different parent')],
          ),
          stateHash: CheckpointStateHasher.hashLines([_line(1, 'B')]),
        ),
      )..id = 2;

      expect(
        () => CheckpointReconstructor.reconstructPostOperation(
          checkpoints: [root, commit],
          targetCheckpointId: commit.id,
        ),
        throwsA(isA<CheckpointIntegrityException>()),
      );
    });
  });
}
