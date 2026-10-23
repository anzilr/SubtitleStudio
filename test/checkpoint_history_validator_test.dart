import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_history_validator.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';

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
  int? parentId,
  required List<SubtitleLine> lines,
  bool isActive = false,
}) {
  return Checkpoint(
    sessionId: 1,
    subtitleCollectionId: 7,
    timestamp: DateTime.utc(2026, 10, 4, 12, 0, id),
    operationType: 'snapshot',
    description: 'Commit $id',
    parentCheckpointId: parentId,
    isActive: isActive,
    checkpointType: 'snapshot',
    deltas: const [],
    snapshot: lines,
    metadata: CheckpointHistoryMetadata.encodePostOperation(
      stateHash: CheckpointStateHasher.hashLines(lines),
    ),
  )..id = id;
}

void main() {
  group('CheckpointHistoryValidator', () {
    test('accepts a healthy branched v2 graph with one HEAD', () {
      final root = _snapshot(id: 1, lines: [_line(1, 'A')]);
      final oldBranch = _snapshot(
        id: 2,
        parentId: 1,
        lines: [_line(1, 'B')],
      );
      final head = _snapshot(
        id: 3,
        parentId: 1,
        lines: [_line(1, 'C')],
        isActive: true,
      );

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: [root, oldBranch, head],
      );

      expect(health.isHealthy, isTrue);
      expect(health.issues, isEmpty);
    });

    test('mixed v2 graph remains healthy with legacy checkpoint as HEAD', () {
      final legacyHead = Checkpoint(
        sessionId: 1,
        subtitleCollectionId: 7,
        timestamp: DateTime.utc(2026, 10, 4, 10),
        operationType: 'legacy',
        description: 'Legacy root',
        parentCheckpointId: null,
        isActive: true,
        checkpointType: 'snapshot',
        deltas: const [],
        snapshot: [_line(1, 'A')],
        metadata: null,
      )..id = 1;

      final v2Snapshot = _snapshot(
        id: 2,
        parentId: 1,
        lines: [_line(1, 'B')],
      );

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: [legacyHead, v2Snapshot],
      );

      expect(health.isHealthy, isTrue);
      expect(health.issues, isEmpty);
    });

    test('reports multiple HEADs in v2 history', () {
      final first = _snapshot(
        id: 1,
        lines: [_line(1, 'A')],
        isActive: true,
      );
      final second = _snapshot(
        id: 2,
        parentId: 1,
        lines: [_line(1, 'B')],
        isActive: true,
      );

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: [first, second],
      );

      expect(health.isHealthy, isFalse);
      expect(
        health.issues.any((issue) => issue.contains('exactly one HEAD')),
        isTrue,
      );
    });

    test('reports missing parent references', () {
      final checkpoint = _snapshot(
        id: 2,
        parentId: 99,
        lines: [_line(1, 'B')],
        isActive: true,
      );

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: [checkpoint],
      );

      expect(health.isHealthy, isFalse);
      expect(
        health.issues.any((issue) => issue.contains('missing parent 99')),
        isTrue,
      );
    });

    test('reports hash corruption through reconstruction validation', () {
      final checkpoint = _snapshot(
        id: 1,
        lines: [_line(1, 'A')],
        isActive: true,
      );
      checkpoint.snapshot.first.original = 'Tampered';

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: [checkpoint],
      );

      expect(health.isHealthy, isFalse);
      expect(
        health.issues.any((issue) => issue.contains('failed reconstruction')),
        isTrue,
      );
    });
  });
}
