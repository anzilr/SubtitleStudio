import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_actions.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_panel.dart';

class FakeHistoryCommands implements HistoryGraphCommands {
  final bool corrupt;
  final bool detached;
  int? lastExpectedHeadId;
  int? lastExpectedTipId;
  final List<HistoryRef> refs;
  final Checkpoint checkpoint;

  FakeHistoryCommands({
    this.corrupt = false,
    this.detached = false,
    String? description,
    String operationType = 'snapshot',
  }) : refs = [
          _ref('HEAD', 'head', 1,
              attached: detached ? null : 'refs/heads/main'),
          _ref('refs/heads/main', 'branch', 1),
        ],
        checkpoint = Checkpoint(
          sessionId: 1,
          subtitleCollectionId: 9,
          timestamp: DateTime.utc(2026, 10, 13),
          operationType: operationType,
          description: description ?? 'Initial state',
          parentCheckpointId: null,
          isActive: true,
          checkpointType: 'snapshot',
          deltas: const [],
          snapshot: const [],
        )..id = 1;

  static HistoryRef _ref(String name, String kind, int id,
          {String? attached}) =>
      HistoryRef(
        sessionId: 1, subtitleCollectionId: 9,
        name: name, kind: kind,
        targetCheckpointId: id,
        symbolicBranchName: attached,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  @override
  Future<CheckpointHistoryGraph> load() async {
    if (corrupt) throw StateError('Bad history');
    return CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: [checkpoint], persistentRefs: refs);
  }

  @override
  Future<CheckpointHistoryGraph> createBookmark({
    required String name, required int checkpointId,
  }) async {
    refs.add(_ref(name, 'bookmark', checkpointId));
    return load();
  }

  @override
  Future<CheckpointHistoryGraph> createBranch({
    required String name, required int checkpointId,
  }) async {
    refs.add(_ref(name, 'branch', checkpointId));
    return load();
  }

  @override
  Future<CheckpointHistoryGraph> renameReference({
    required String name, required String newName,
  }) async {
    final target = refs.firstWhere((item) => item.name == name);
    target.name = newName;
    return load();
  }

  @override
  Future<CheckpointHistoryGraph> deleteReference(String name) async {
    refs.removeWhere((item) => item.name == name);
    return load();
  }

  @override
  Future<CheckpointHistoryGraph?> checkoutBranch(String name, {
    int? ifCurrentHeadId,
    int? ifBranchTipId,
  }) async {
    lastExpectedHeadId = ifCurrentHeadId;
    lastExpectedTipId = ifBranchTipId;
    return null;
  }

  @override
  Future<CheckpointHistoryGraph?> checkoutCommit(int checkpointId, {
    int? ifCurrentHeadId,
  }) async {
    lastExpectedHeadId = ifCurrentHeadId;
    return null;
  }
}

Widget _host(FakeHistoryCommands actions) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 650,
        child: CheckpointHistoryPanel(
          sessionId: 1,
          commands: actions,
          onCheckpointRestored: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('displays actual HEAD and named branch labels', (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands()));
    await tester.pumpAndSettle();
    expect(find.text('Editing: Main edits'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-1')), findsOneWidget);
    // The visual history track is drawn next to the existing action card;
    // graph rendering must not remove the accessible commit information.
    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-ref-menu-refs/heads/main')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-head-status')), findsOneWidget);
    expect(find.text('Main edits · In use'), findsWidgets);
    expect(find.textContaining('current branch'), findsNothing);
    expect(find.text('main'), findsNothing);
    expect(find.byKey(const ValueKey('history-legend')), findsOneWidget);
    expect(find.text('Earlier versions'), findsOneWidget);
    expect(find.text('History split'), findsOneWidget);
  });

  testWidgets('named alternate path remains recognizable and active',
      (tester) async {
    final commands = FakeHistoryCommands();
    commands.refs[0].symbolicBranchName = 'refs/heads/review';
    commands.refs.add(FakeHistoryCommands._ref(
      'refs/heads/review', 'branch', 1,
    ));
    await tester.pumpWidget(_host(commands));
    await tester.pumpAndSettle();
    expect(find.text('Editing: review'), findsOneWidget);
    expect(find.text('review · In use'), findsWidgets);
    expect(find.text('Main edits'), findsWidgets);
    expect(find.textContaining('current branch'), findsNothing);
    expect(commands.refs[0].symbolicBranchName, 'refs/heads/review');
  });

  testWidgets('bookmark menu creates and displays persistent-style ref',
      (tester) async {
    final fake = FakeHistoryCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-node-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark this version'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'review');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.refs.any((item) =>
        item.name == 'refs/bookmarks/review' &&
        item.targetCheckpointId == 1), isTrue);
    expect(find.byKey(
        const ValueKey('history-ref-menu-refs/bookmarks/review')),
        findsOneWidget);
  });

  testWidgets('visual history humanizes automatic subtitle edit labels',
      (tester) async {
    final commands = FakeHistoryCommands(
      operationType: 'edit',
      description: 'Edited line 12',
    );
    await tester.pumpWidget(_host(commands));
    await tester.pumpAndSettle();
    expect(find.text('Edited subtitle 12'), findsOneWidget);
    expect(find.text('Edited line 12'), findsNothing);
    expect(commands.checkpoint.description, 'Edited line 12');
    expect(commands.checkpoint.operationType, 'edit');
  });

  testWidgets('custom save point title stays exactly as entered',
      (tester) async {
    final commands = FakeHistoryCommands(
      operationType: 'manual',
      description: 'Before final review',
    );
    await tester.pumpWidget(_host(commands));
    await tester.pumpAndSettle();
    expect(find.text('Before final review'), findsOneWidget);
    expect(commands.checkpoint.description, 'Before final review');
  });

  testWidgets('corrupt graph shows retry rather than fake history',
      (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands(corrupt: true)));
    await tester.pumpAndSettle();
    expect(find.text('Cannot display inconsistent checkpoint history.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-graph-list')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('checkout confirmation passes observed HEAD to guard races',
      (tester) async {
    final fake = FakeHistoryCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-node-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore this version'));
    await tester.pumpAndSettle();
    expect(find.textContaining('on a separate editing path'), findsOneWidget);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(find.textContaining('History changed before the restore'), findsOneWidget);
    expect(find.text('Editing: Main edits'), findsOneWidget);
  });


  testWidgets('detached history explains that no branch is selected',
      (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands(detached: true)));
    await tester.pumpAndSettle();
    expect(find.text('Editing from version #1 · Separate path'), findsOneWidget);
    expect(find.text('Editing: Main edits'), findsNothing);
    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
  });

  testWidgets('protected main branch cannot be renamed or deleted in menu',
      (tester) async {
    final fake = FakeHistoryCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('history-ref-menu-refs/heads/main')));
    await tester.pumpAndSettle();
    expect(find.text('Use this editing path'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('restoring a bookmark keeps branch checkout distinct',
      (tester) async {
    final fake = FakeHistoryCommands();
    fake.refs.add(FakeHistoryCommands._ref(
      'refs/bookmarks/review', 'bookmark', 1,
    ));
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('history-ref-menu-refs/bookmarks/review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore bookmarked version'));
    await tester.pumpAndSettle();
    expect(find.textContaining('editing paths and bookmarks stay available'),
        findsOneWidget);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(fake.lastExpectedHeadId, 1);
    expect(fake.lastExpectedTipId, isNull);
  });

  testWidgets('named checkout guards both HEAD and observed branch tip',
      (tester) async {
    final fake = FakeHistoryCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
      const ValueKey('history-ref-menu-refs/heads/main')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this editing path'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open the saved subtitles from "Main edits"'),
        findsOneWidget);
    await tester.tap(find.text('Use path').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(fake.lastExpectedTipId, 1);
    expect(find.text('Editing: Main edits'), findsOneWidget);
  });

  testWidgets('list view hides decorative lanes but keeps version actions',
      (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-rail-1')), findsNothing);
    expect(find.byKey(const ValueKey('history-legend')), findsNothing);
    expect(find.text('Project started'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-node-menu-1')), findsOneWidget);
    expect(find.byTooltip('Show version map'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('history-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-legend')), findsOneWidget);
  });

  testWidgets('compact manager groups paths and bookmarks with safe actions',
      (tester) async {
    final fake = FakeHistoryCommands();
    fake.refs.add(FakeHistoryCommands._ref(
      'refs/heads/review', 'branch', 1,
    ));
    fake.refs.add(FakeHistoryCommands._ref(
      'refs/bookmarks/before-review', 'bookmark', 1,
    ));
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-manage-references')));
    await tester.pumpAndSettle();
    expect(find.text('Editing paths & bookmarks'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-manage-refs/heads/main')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-manage-refs/heads/review')),
        findsOneWidget);
    expect(find.byKey(
        const ValueKey('history-manage-refs/bookmarks/before-review')),
        findsOneWidget);

    await tester.tap(find.byKey(
        const ValueKey('history-manage-menu-refs/heads/main')));
    await tester.pumpAndSettle();
    expect(find.text('Use this editing path'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Editing paths & bookmarks'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
        const ValueKey('history-manage-menu-refs/heads/review')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'final-review');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.refs.any((ref) => ref.name == 'refs/heads/final-review'),
        isTrue);
    expect(fake.refs.any((ref) => ref.name == 'refs/heads/main'), isTrue);
    expect(fake.refs.any((ref) => ref.name == 'refs/bookmarks/before-review'),
        isTrue);
    expect(find.text('Editing: Main edits'), findsOneWidget);
  });

  testWidgets('history toolbar fits narrow mobile view', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_host(FakeHistoryCommands()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('history-manage-references')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-view-toggle')),
        findsOneWidget);
  });
}
