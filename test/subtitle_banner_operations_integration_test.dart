import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/operations/subtitle_banner_operations.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
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
  late SubtitleRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = SubtitleRepository(
      harness.isar,
      CheckpointRepository(harness.isar),
    );
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('banner insertion is one atomic v2 snapshot commit with undo/redo',
      () async {
    final originalLines = [
      _line(
        index: 1,
        text: 'A',
        start: '00:00:30,000',
        end: '00:00:31,000',
      ),
      _line(
        index: 2,
        text: 'B',
        start: '00:01:00,000',
        end: '00:01:01,000',
      ),
    ];

    late int collectionId;
    late int sessionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'banner.srt',
          encoding: 'UTF-8',
          lines: originalLines,
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(
          subtitleCollectionId: collectionId,
          fileName: 'banner.srt',
        ),
      );
    });

    final history = CheckpointRepository(harness.isar);
    final rootId = await history.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
    );

    expect(
      await SubtitleBannerOperations.insertBanners(
        subtitleRepository: repository,
        subtitleCollectionId: collectionId,
        sessionId: sessionId,
        currentSubtitleLines: originalLines,
        beginningText: 'Banner',
        middleText: '',
        endText: '',
        includeBeginning: true,
        includeMiddle: false,
        includeEnd: false,
        customPositions: BannerPositions(
          beginningPosition: const Duration(seconds: 5),
          middlePosition: const Duration(seconds: 45),
          endPosition: const Duration(seconds: 70),
        ),
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
    expect(commit.parentCheckpointId, rootId);
    expect(CheckpointHistoryMetadata.isPostOperation(commit), isTrue);
    expect(CheckpointHistoryMetadata.stateHash(commit), isNotNull);
    expect(commit.checkpointType, 'snapshot');
    expect(commit.operationType, 'add');

    var stored = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      stored!.lines.map((line) => line.original).toList(),
      ['Banner', 'A', 'B'],
    );

    expect(await history.undo(sessionId: sessionId), isTrue);
    stored = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      stored!.lines.map((line) => line.original).toList(),
      ['A', 'B'],
    );

    expect(
      await history.redoToCheckpoint(
        checkpointId: commit.id,
        sessionId: sessionId,
      ),
      isTrue,
    );
    stored = await harness.isar.subtitleCollections.get(collectionId);
    expect(
      stored!.lines.map((line) => line.original).toList(),
      ['Banner', 'A', 'B'],
    );
  });
}
