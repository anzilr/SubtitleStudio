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

  FakeHistoryCommands({this.corrupt = false, this.detached = false})
      : refs = [
          _ref('HEAD', 'head', 1,
              attached: detached ? null : 'refs/heads/main'),
          _ref('refs/heads/main', 'branch', 1),
        ],
        checkpoint = Checkpoint(
          sessionId: 1,
          subtitleCollectionId: 9,
          timestamp: DateTime.utc(2026, 10, 13),
          operationType: 'snapshot',
          description: 'Initial state',
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
    expect(find.text('Working on main'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-1')), findsOneWidget);
    // The visual history track is drawn next to the existing action card;
    // graph rendering must not remove the accessible commit information.
    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-ref-menu-refs/heads/main')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-head-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-legend')), findsOneWidget);
    expect(find.text('Earlier versions'), findsOneWidget);
    expect(find.text('Branch point'), findsOneWidget);
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
    await tester.tap(find.text('Check out commit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('without switching to a branch'), findsOneWidget);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(find.textContaining('History changed before the restore'), findsOneWidget);
    expect(find.text('Working on main'), findsOneWidget);
  });


  testWidgets('detached history explains that no branch is selected',
      (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands(detached: true)));
    await tester.pumpAndSettle();
    expect(find.text('Version #1 · Not on a branch'), findsOneWidget);
    expect(find.text('Working on main'), findsNothing);
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
    expect(find.text('Switch to branch'), findsOneWidget);
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
    expect(find.textContaining('branches and bookmarks stay unchanged'),
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
    await tester.tap(find.text('Switch to branch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('current branch'), findsOneWidget);
    await tester.tap(find.text('Switch').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(fake.lastExpectedTipId, 1);
    expect(find.text('Working on main'), findsOneWidget);
  });
}
