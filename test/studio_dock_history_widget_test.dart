import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

CheckpointHistoryGraph graph(int head, {bool fork = false}) {
  final commits = [
    for (final (id, parent) in <(int, int?)>[
      (1, null), (2, 1), if (fork) (3, 1),
    ])
      Checkpoint(
        sessionId: 1, subtitleCollectionId: 9,
        timestamp: DateTime.utc(2026, 10, 24),
        operationType: id == 1 ? 'snapshot' : 'edit',
        description: id == 1 ? 'Initial state' : 'Edited line $id',
        parentCheckpointId: parent, isActive: id == head,
        checkpointType: 'snapshot', deltas: const [], snapshot: const [],
      )..id = id,
  ];
  return CheckpointHistoryGraph.build(
    sessionId: 1,
    checkpoints: commits,
    persistentRefs: [
      HistoryRef(
        sessionId: 1, subtitleCollectionId: 9, name: 'HEAD',
        kind: 'head', targetCheckpointId: head,
        createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      ),
      HistoryRef(
        sessionId: 1, subtitleCollectionId: 9,
        name: 'refs/heads/main', kind: 'branch',
        targetCheckpointId: fork ? 3 : 2,
        createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      ),
    ],
  );
}

const first = StudioDockCue(
  id: 1, start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original text', edited: 'Edited text',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('desktop history can host the full shared checkpoint interface',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: [first],
      checkpointHistoryPanel: Center(
        child: Text('Shared checkpoint graph and bookmarks'),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-1')));
    await tester.pumpAndSettle();
    expect(find.text('Shared checkpoint graph and bookmarks'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-history-list')), findsNothing);
  });

  Future<void> launch(
    WidgetTester tester, {
    required Future<CheckpointHistoryGraph> Function() load,
    required Future<StudioDockCueUpdate?> Function(int, int, int) restore,
    Future<bool> Function(int, String)? applyText,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true, initialCues: const [first],
      onLoadHistory: load, onRestoreHistory: restore,
      onApplyCueText: applyText,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Undo and Redo refresh all rows and displayed history',
      (tester) async {
    var head = 2;
    final moves = <String>[];
    await launch(tester,
      load: () async => graph(head),
      restore: (target, expected, selected) async {
        moves.add('$target:$expected:$selected');
        head = target;
        return StudioDockCueUpdate(
          cues: [first.copyWith(edited:
              target == 1 ? 'Edited text' : 'Restored version')],
          selectedCueId: 1,
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('studio-dock-undo')));
    await tester.pumpAndSettle();
    expect(moves, ['1:2:1']);
    expect(tester.widget<IconButton>(find.byKey(
      const ValueKey('studio-dock-undo'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('studio-dock-redo')));
    await tester.pumpAndSettle();
    expect(moves, ['1:2:1', '2:1:1']);
    expect(find.text('Restored version'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('rail-1')));
    await tester.pumpAndSettle();
    expect(find.text('Editing history'), findsOneWidget);
    expect(find.text('Edited subtitle 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-history-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forked Redo requires choosing a saved path', (tester) async {
    var head = 1;
    final moves = <int>[];
    await launch(tester,
      load: () async => graph(head, fork: true),
      restore: (target, expected, _) async {
        expect(expected, 1);
        moves.add(target);
        head = target;
        return const StudioDockCueUpdate(cues: [first], selectedCueId: 1);
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-dock-redo')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a version to redo'), findsOneWidget);
    expect(moves, isEmpty);
    await tester.tap(find.byKey(const ValueKey('studio-redo-choice-3')));
    await tester.pumpAndSettle();
    expect(moves, [3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved text draft blocks history restoration on Cancel',
      (tester) async {
    var calls = 0;
    await launch(tester,
      load: () async => graph(2),
      restore: (_, __, ___) async {
        calls++;
        return null;
      },
      applyText: (_, __) async => true,
    );
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Uncommitted draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-undo')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
