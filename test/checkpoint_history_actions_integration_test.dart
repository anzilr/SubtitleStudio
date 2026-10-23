import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_actions.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line() => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = 'Hello'
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

void main() {
  late TestIsarHarness harness;

  setUp(() async {
    harness = await TestIsarHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  test('empty session history is safe and does not create references',
      () async {
    final history = CheckpointRepository(harness.isar);
    final graph = await history.getHistoryGraph(424242);
    expect(graph.nodes, isEmpty);
    expect(graph.references, isEmpty);
    expect(await harness.isar.historyRefs.count(), 0);
  });

  test('actions use persisted refs and return the durable graph',
      () async {
    late int sessionId;
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'graph.srt', encoding: 'UTF-8', lines: [_line()],
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(fileName: 'graph.srt', subtitleCollectionId: collectionId),
      );
    });
    final repository = CheckpointRepository(harness.isar);
    final actions = CheckpointHistoryActions(
      repository, sessionId: sessionId);
    final initialId = await repository.createInitialSnapshot(
      sessionId: sessionId, subtitleCollectionId: collectionId);
    expect(initialId, greaterThan(0));

    var graph = await actions.load();
    expect(graph.headCheckpointId, initialId);
    expect(graph.attachedBranchName, 'refs/heads/main');
    expect(graph.nodes.single.references.map((r) => r.name),
        ['HEAD', 'refs/heads/main']);
    final checkpointCount = await harness.isar.checkpoints.count();

    graph = await actions.createBranch(
      name: 'refs/heads/review', checkpointId: initialId);
    expect(graph.references.map((r) => r.name), [
      'HEAD', 'refs/heads/main', 'refs/heads/review',
    ]);
    graph = await actions.createBookmark(
      name: 'refs/bookmarks/first', checkpointId: initialId);
    expect(graph.nodes.single.references, hasLength(4));
    graph = await actions.renameReference(
      name: 'refs/bookmarks/first',
      newName: 'refs/bookmarks/approved');
    expect(graph.references.any(
        (r) => r.name == 'refs/bookmarks/approved'), isTrue);

    graph = (await actions.checkoutBranch('refs/heads/review'))!;
    expect(graph.attachedBranchName, 'refs/heads/review');
    expect(graph.references.firstWhere(
        (r) => r.name == 'refs/heads/review').canDelete, isFalse);
    expect(await actions.checkoutBranch('refs/heads/does-not-exist'), isNull);
    graph = (await actions.checkoutCommit(initialId))!;
    expect(graph.isDetached, isTrue);
    expect(graph.references.firstWhere(
        (r) => r.name == 'refs/heads/review').canDelete, isTrue);

    graph = await actions.deleteReference('refs/bookmarks/approved');
    expect(graph.references.any(
        (r) => r.name == 'refs/bookmarks/approved'), isFalse);
    expect(await harness.isar.checkpoints.count(), checkpointCount);
    expect(await harness.isar.historyRefs.count(), 3);
  });

  test('checkout refuses a stale HEAD and stale named branch tip', () async {
    late int sessionId;
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'checkout-race.srt',
          encoding: 'UTF-8',
          lines: [_line()],
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(
          fileName: 'checkout-race.srt',
          subtitleCollectionId: collectionId,
        ),
      );
    });
    final repository = CheckpointRepository(harness.isar);
    final actions = CheckpointHistoryActions(repository, sessionId: sessionId);
    final root = await repository.createInitialSnapshot(
      sessionId: sessionId, subtitleCollectionId: collectionId);
    await actions.createBranch(
      name: 'refs/heads/topic', checkpointId: root);
    final next = await repository.createManualCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
      customDescription: 'Newer state',
    );
    expect(next, isNot(root));

    // A confirmation made at the old HEAD must not detach a newer commit.
    expect(await actions.checkoutCommit(
      root, ifCurrentHeadId: root), isNull);
    expect((await repository.getHeadCheckpoint(sessionId))!.id, next);

    // A branch label that changed after the dialog opened must be rejected.
    expect(await actions.checkoutBranch(
      'refs/heads/topic',
      ifCurrentHeadId: next,
      ifBranchTipId: next,
    ), isNull);
    expect((await repository.getHeadCheckpoint(sessionId))!.id, next);

    // With both observed values current, branch switching succeeds.
    final switched = await actions.checkoutBranch(
      'refs/heads/topic',
      ifCurrentHeadId: next,
      ifBranchTipId: root,
    );
    expect(switched?.headCheckpointId, root);
    expect(switched?.attachedBranchName, 'refs/heads/topic');

    // A new commit advances the attached branch only.
    final movedTip = await repository.createManualCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: collectionId,
      customDescription: 'Topic change',
    );
    expect(movedTip, isNot(root));
    expect(await actions.checkoutBranch(
      'refs/heads/topic',
      ifCurrentHeadId: movedTip,
      ifBranchTipId: root,
    ), isNull);
    expect((await repository.getHeadCheckpoint(sessionId))!.id, movedTip);
  });

  test('creating a branch after restoring an earlier point persists the ref',
      () async {
    late int sessionId;
    late int collectionId;
    await harness.isar.writeTxn(() async {
      collectionId = await harness.isar.subtitleCollections.put(
        SubtitleCollection(
          fileName: 'restored-history.srt', encoding: 'UTF-8',
          lines: [_line()],
        ),
      );
      sessionId = await harness.isar.sessions.put(
        Session(fileName: 'restored-history.srt',
            subtitleCollectionId: collectionId),
      );
    });
    final repository = CheckpointRepository(harness.isar);
    final actions = CheckpointHistoryActions(repository, sessionId: sessionId);
    final firstPoint = await repository.createInitialSnapshot(
        sessionId: sessionId, subtitleCollectionId: collectionId);
    final secondPoint = await repository.createManualCheckpoint(
        sessionId: sessionId, subtitleCollectionId: collectionId,
        customDescription: 'Before restore');
    expect(secondPoint, isNot(firstPoint));

    final restored = await actions.checkoutCommit(firstPoint);
    expect(restored?.isDetached, isTrue);
    final created = await actions.createBranch(
        name: 'refs/heads/after-restore', checkpointId: firstPoint);
    expect(created.isDetached, isTrue);
    expect(created.headCheckpointId, firstPoint);
    expect(created.references.singleWhere(
        (ref) => ref.name == 'refs/heads/after-restore').checkpointId,
        firstPoint);
    expect((await actions.load()).references.any(
        (ref) => ref.name == 'refs/heads/after-restore'), isTrue);
    expect((await repository.getHeadCheckpoint(sessionId))!.id, firstPoint);
  });
}
