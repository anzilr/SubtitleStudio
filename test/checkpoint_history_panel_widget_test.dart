import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_panel.dart';

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

Future<({int sessionId, int collectionId})> _seed(TestIsarHarness harness) async {
  late int sessionId;
  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'mobile-history.srt',
        encoding: 'UTF-8',
        lines: [_line()],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(
        fileName: 'mobile-history.srt',
        subtitleCollectionId: collectionId,
      ),
    );
  });
  return (sessionId: sessionId, collectionId: collectionId);
}

Widget _testHost(TestIsarHarness harness, int sessionId,
    {VoidCallback? onRestored}) {
  return ProviderScope(
    overrides: [isarProvider.overrideWithValue(harness.isar)],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 670,
          child: CheckpointHistoryPanel(
            sessionId: sessionId,
            onCheckpointRestored: onRestored ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  late TestIsarHarness harness;

  setUp(() async {
    harness = await TestIsarHarness.open();
  });

  tearDown(() async {
    await harness.close();
  });

  testWidgets('shows real HEAD and branch refs with a persistent commit',
      (tester) async {
    final ids = await _seed(harness);
    final repository = CheckpointRepository(harness.isar);
    final root = await repository.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    await tester.pumpWidget(_testHost(harness, ids.sessionId));
    await tester.pumpAndSettle();

    expect(find.text('On main'), findsOneWidget);
    expect(find.byKey(ValueKey('history-commit-' + root.toString())),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-ref-menu-refs/heads/main')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-head-status')), findsOneWidget);
  });

  testWidgets('creates a bookmark using the session-scoped UI action',
      (tester) async {
    final ids = await _seed(harness);
    final repository = CheckpointRepository(harness.isar);
    final root = await repository.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    await tester.pumpWidget(_testHost(harness, ids.sessionId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
      ValueKey('history-node-menu-' + root.toString())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark this commit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'review');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final persisted = await repository.getPersistentReferences(ids.sessionId);
    expect(persisted.any((ref) =>
        ref.name == 'refs/bookmarks/review' &&
        ref.targetCheckpointId == root), isTrue);
    expect(find.byKey(
        const ValueKey('history-ref-menu-refs/bookmarks/review')),
        findsOneWidget);
    expect(await harness.isar.checkpoints.count(), 1);
  });

  testWidgets('reports corrupt persisted history instead of fake graph',
      (tester) async {
    final ids = await _seed(harness);
    await harness.isar.writeTxn(() async {
      await harness.isar.checkpoints.put(Checkpoint(
        sessionId: ids.sessionId,
        subtitleCollectionId: ids.collectionId,
        timestamp: DateTime.utc(2026),
        operationType: 'snapshot',
        description: 'Bad HEAD',
        parentCheckpointId: 987654,
        isActive: true,
        checkpointType: 'snapshot',
        deltas: const [],
        snapshot: [_line()],
      ));
    });
    await tester.pumpWidget(_testHost(harness, ids.sessionId));
    await tester.pumpAndSettle();
    expect(find.text('Cannot display inconsistent checkpoint history.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-graph-list')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
