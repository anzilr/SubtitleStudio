import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/services/hearing_impaired_cleanup_service.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String original) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  late TestIsarHarness harness;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('cleanup is one atomic v2 commit with working undo and redo', () async {
    late int collectionId;
    late int sessionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'hearing-cleanup.srt',
          encoding: 'UTF-8',
          lines: [
            _line(1, '[door slams]'),
            _line(2, 'JOHN: Hello'),
            _line(3, 'Keep this'),
          ],
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(
          fileName: 'hearing-cleanup.srt',
          subtitleCollectionId: collectionId,
        ),
      );
    });

    final checkpoints = CheckpointRepository(harness.isar);
    final initialId = await checkpoints.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
    );

    final result = await HearingImpairedCleanupService.execute(
      isar: harness.isar,
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
    );

    expect(result.originalCount, 3);
    expect(result.removedCount, 1);
    expect(result.modifiedCount, 1);
    expect(result.remainingCount, 2);

    var collection = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      collection!.lines.map((line) => line.original).toList(),
      ['Hello', 'Keep this'],
    );

    final history = await harness.isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .findAll();
    expect(history, hasLength(2));

    final cleanup = history.firstWhere(
      (checkpoint) => checkpoint.operationType == 'batch',
    );
    expect(CheckpointHistoryMetadata.isPostOperation(cleanup), isTrue);
    expect(cleanup.parentCheckpointId, initialId);
    expect(cleanup.checkpointType, 'snapshot');
    expect(
      cleanup.snapshot.map((line) => line.original).toList(),
      ['Hello', 'Keep this'],
    );

    expect(
      await checkpoints.undoToCheckpoint(
        checkpointId: initialId,
        sessionId: sessionId,
      ),
      isTrue,
    );
    collection = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      collection!.lines.map((line) => line.original).toList(),
      ['[door slams]', 'JOHN: Hello', 'Keep this'],
    );

    expect(
      await checkpoints.redoToCheckpoint(
        checkpointId: cleanup.id,
        sessionId: sessionId,
      ),
      isTrue,
    );
    collection = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      collection!.lines.map((line) => line.original).toList(),
      ['Hello', 'Keep this'],
    );
  });
}
