import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(String text) {
  return SubtitleLine()
    ..index = 1
    ..startTime = '00:00:01,000'
    ..endTime = '00:00:02,000'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  late TestIsarHarness harness;
  late SubtitleRepository subtitles;
  late CheckpointRepository history;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    history = CheckpointRepository(harness.isar);
    subtitles = SubtitleRepository(harness.isar, history);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('tight retention preserves the most recent alternate redo branch',
      () async {
    late int collectionId;
    late int sessionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'branch-retention.srt',
          encoding: 'UTF-8',
          lines: [_line('A')],
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(
          subtitleCollectionId: collectionId,
          fileName: 'branch-retention.srt',
        ),
      );
    });

    await PreferencesStore(harness.isar).update((preferences) {
      preferences.maxCheckpoints = 3;
      preferences.checkpointStrategy = 'snapshot';
    });

    await history.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
    );

    expect(
      await subtitles.saveLineChanges(
        collectionId,
        _line('A1'),
        sessionId: sessionId,
      ),
      isTrue,
    );
    final forkPoint = await history.getHeadCheckpoint(sessionId);
    expect(forkPoint, isNotNull);

    expect(
      await subtitles.saveLineChanges(
        collectionId,
        _line('A2'),
        sessionId: sessionId,
      ),
      isTrue,
    );
    final oldBranchTip = await history.getHeadCheckpoint(sessionId);
    expect(oldBranchTip, isNotNull);

    expect(
      await history.checkoutCheckpoint(
        checkpointId: forkPoint!.id,
        sessionId: sessionId,
      ),
      isTrue,
    );

    expect(
      await subtitles.saveLineChanges(
        collectionId,
        _line('A3'),
        sessionId: sessionId,
      ),
      isTrue,
    );
    final newBranchTip = await history.getHeadCheckpoint(sessionId);
    expect(newBranchTip, isNotNull);
    expect(newBranchTip!.id, isNot(oldBranchTip!.id));

    // The configured limit is intentionally exceeded to keep recent branch
    // recovery safe. Cleanup may prune older abandoned branches later.
    final stored = await harness.isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .findAll();
    expect(stored.length, greaterThan(3));
    expect(
      stored.any((checkpoint) => checkpoint.id == oldBranchTip.id),
      isTrue,
    );

    expect(
      await history.checkoutCheckpoint(
        checkpointId: forkPoint.id,
        sessionId: sessionId,
      ),
      isTrue,
    );

    final redoOptions = await history.getRedoOptions(sessionId);
    expect(
      redoOptions.map((checkpoint) => checkpoint.id).toSet(),
      {oldBranchTip.id, newBranchTip.id},
    );
  });
}
