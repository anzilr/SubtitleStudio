import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line({
  required int index,
  required String text,
  required String start,
  required String end,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = start
    ..endTime = end
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  late TestIsarHarness harness;
  late WaveformSubtitleRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = WaveformSubtitleRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('waveform timing edit is one atomic v2 commit with undo/redo', () async {
    late int collectionId;
    late int sessionId;

    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'waveform.srt',
          encoding: 'UTF-8',
          lines: [
            _line(
              index: 1,
              text: 'A',
              start: '00:00:01,000',
              end: '00:00:02,000',
            ),
          ],
        ),
      );

      sessionId = await harness.isar.sessions.put(
        Session(
          subtitleCollectionId: collectionId,
          fileName: 'waveform.srt',
        ),
      );
    });

    final history = CheckpointRepository(harness.isar);
    final rootId = await history.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
    );

    final edited = _line(
      index: 1,
      text: 'A',
      start: '00:00:01,500',
      end: '00:00:02,500',
    );

    expect(
      await repository.updateLinesWithHistory(
        subtitleCollectionId: collectionId,
        sessionId: sessionId,
        updatedLines: [edited],
      ),
      isTrue,
    );

    final checkpoints = await harness.isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByTimestamp()
        .findAll();

    expect(checkpoints, hasLength(2));
    final commit = checkpoints.last;
    expect(CheckpointHistoryMetadata.isPostOperation(commit), isTrue);
    expect(CheckpointHistoryMetadata.stateHash(commit), isNotNull);
    expect(commit.parentCheckpointId, rootId);
    expect(commit.operationType, 'edit');

    final stored = await harness.isar.subtitleCollections.get(collectionId);
    expect(stored!.lines.single.startTime, '00:00:01,500');
    expect(stored.lines.single.endTime, '00:00:02,500');

    expect(
      await history.undo(sessionId: sessionId),
      isTrue,
    );
    final undone = await harness.isar.subtitleCollections.get(collectionId);
    expect(undone!.lines.single.startTime, '00:00:01,000');
    expect(undone.lines.single.endTime, '00:00:02,000');

    expect(
      await history.redoToCheckpoint(
        checkpointId: commit.id,
        sessionId: sessionId,
      ),
      isTrue,
    );
    final redone = await harness.isar.subtitleCollections.get(collectionId);
    expect(redone!.lines.single.startTime, '00:00:01,500');
    expect(redone.lines.single.endTime, '00:00:02,500');
  });
}
