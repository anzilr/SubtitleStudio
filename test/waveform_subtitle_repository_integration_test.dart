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

Future<({int sessionId, int collectionId})> _seedWaveform(
  TestIsarHarness harness,
) async {
  late int sessionId;
  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'waveform-safety.srt',
        encoding: 'UTF-8',
        lines: [
          _line(
            index: 1,
            text: 'Unchanged translation',
            start: '00:00:01,000',
            end: '00:00:02,000',
          )..comment = 'Keep this review'
           ..marked = true
           ..resolved = true,
        ],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(
        subtitleCollectionId: collectionId,
        fileName: 'waveform-safety.srt',
      ),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
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

  test('waveform timing changes keep newer annotations and subtitle text',
      () async {
    final ids = await _seedWaveform(harness);
    final old = (await harness.isar.subtitleCollections.get(ids.collectionId))!
        .lines.single;
    final stale = _line(
      index: 1,
      text: 'Stale UI text',
      start: '00:00:03,000',
      end: '00:00:04,000',
    );

    // Only start/end are owned by the waveform; cached text must not win.
    expect(await repository.updateLinesWithHistory(
      subtitleCollectionId: ids.collectionId,
      sessionId: ids.sessionId,
      updatedLines: [stale],
    ), isTrue);
    final fresh = (await harness.isar.subtitleCollections.get(ids.collectionId))!
        .lines.single;
    expect(fresh.original, old.original);
    expect(fresh.comment, 'Keep this review');
    expect(fresh.marked, isTrue);
    expect(fresh.resolved, isTrue);
    expect(fresh.startTime, '00:00:03,000');
    expect((await CheckpointRepository(harness.isar)
        .validateHistory(ids.sessionId)).isHealthy, isTrue);
  });

  test('waveform rejects a stale edit without losing intervening text',
      () async {
    final ids = await _seedWaveform(harness);
    final before = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!.lines.single;
    final expected = _line(
      index: 1,
      text: before.original,
      start: before.startTime,
      end: before.endTime,
    )..marked = before.marked
     ..comment = before.comment
     ..resolved = before.resolved;
    await harness.isar.writeTxn(() async {
      final live =
          (await harness.isar.subtitleCollections.get(ids.collectionId))!;
      live.lines.first.original = 'Concurrent edit';
      await harness.isar.subtitleCollections.put(live);
    });

    expect(await repository.updateLinesWithHistory(
      subtitleCollectionId: ids.collectionId,
      sessionId: ids.sessionId,
      expectedLines: [expected],
      updatedLines: [
        _line(
          index: 1,
          text: expected.original,
          start: '00:00:03,000',
          end: '00:00:04,000',
        ),
      ],
    ), isFalse);
    final current = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!.lines.single;
    expect(current.original, 'Concurrent edit');
    expect(current.startTime, '00:00:01,000');
    expect(await harness.isar.checkpoints.count(), 0);
  });

  test('waveform no-op succeeds without a redundant V2 commit', () async {
    final ids = await _seedWaveform(harness);
    final history = CheckpointRepository(harness.isar);
    await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    final original = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!.lines.single;

    expect(await repository.updateLinesWithHistory(
      subtitleCollectionId: ids.collectionId,
      sessionId: ids.sessionId,
      updatedLines: [original],
      expectedLines: [original],
    ), isTrue);
    expect((await history.getCheckpointsForSession(ids.sessionId)), hasLength(1));
  });

  test('legacy waveform batch rejects duplicates and missing cues atomically',
      () async {
    final ids = await _seedWaveform(harness);
    final changed = _line(
      index: 1,
      text: 'Ignored stale value',
      start: '00:00:05,000',
      end: '00:00:06,000',
    );
    final missing = _line(
      index: 99,
      text: 'Missing',
      start: '00:00:07,000',
      end: '00:00:08,000',
    );
    expect(await repository.updateLines(
      ids.collectionId, [changed, missing],
    ), isFalse);
    expect(await repository.updateLines(
      ids.collectionId, [changed, changed],
    ), isFalse);
    final current = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!.lines.single;
    expect(current.startTime, '00:00:01,000');
    expect(current.comment, 'Keep this review');
    expect(await repository.updateLines(ids.collectionId, [changed]), isTrue);
    final next = (await harness.isar.subtitleCollections
        .get(ids.collectionId))!.lines.single;
    expect(next.startTime, '00:00:05,000');
    expect(next.original, 'Unchanged translation');
    expect(next.comment, 'Keep this review');
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
