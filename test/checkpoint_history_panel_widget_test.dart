import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_actions.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_panel.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_rail.dart';

class FakeHistoryCommands implements HistoryGraphCommands {
  final bool corrupt;
  final bool detached;
  bool rejectBranchCreation = false;
  int? lastExpectedHeadId;
  int? lastExpectedTipId;
  final List<HistoryRef> refs;
  final Checkpoint checkpoint;
  final List<Checkpoint> additionalCheckpoints;

  FakeHistoryCommands({
    this.corrupt = false,
    this.detached = false,
    String? description,
    String operationType = 'snapshot',
    List<Checkpoint>? additionalCheckpoints,
  }) : refs = [
          _ref('HEAD', 'head', 1,
              attached: detached ? null : 'refs/heads/main'),
          _ref('refs/heads/main', 'branch', 1),
        ],
        additionalCheckpoints = additionalCheckpoints ?? <Checkpoint>[],
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
      sessionId: 1, checkpoints: [checkpoint, ...additionalCheckpoints],
      persistentRefs: refs);
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
    if (rejectBranchCreation) {
      throw StateError('History reference name already exists or overlaps.');
    }
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

Checkpoint _childPoint(int id, int parent, {bool active = false}) =>
    Checkpoint(
      sessionId: 1,
      subtitleCollectionId: 9,
      timestamp: DateTime.utc(2026, 10, 22),
      operationType: 'edit',
      description: 'Edited line $id',
      parentCheckpointId: parent,
      isActive: active,
      deltas: const [],
      snapshot: const [],
    )..id = id;

FakeHistoryCommands _forkedCommands() {
  final fake = FakeHistoryCommands(additionalCheckpoints: [
    _childPoint(2, 1),
    _childPoint(3, 2, active: true),
    _childPoint(4, 2),
  ]);
  fake.checkpoint.isActive = false;
  fake.refs[0].targetCheckpointId = 3;
  fake.refs[1].targetCheckpointId = 3;
  fake.refs.add(FakeHistoryCommands._ref(
      'refs/heads/review', 'branch', 4));
  return fake;
}

void main() {
  testWidgets('each branch keeps a colored chip even when not filtered',
      (tester) async {
    await tester.pumpWidget(_host(_forkedCommands()));
    await tester.pumpAndSettle();
    final main = tester.widget<ChoiceChip>(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/main')));
    final review = tester.widget<ChoiceChip>(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/review')));
    expect(main.selected, isFalse);
    expect(review.selected, isFalse);
    expect(main.backgroundColor, isNotNull);
    expect(review.backgroundColor, isNotNull);
    expect(main.backgroundColor, isNot(review.backgroundColor));
    expect(main.labelStyle?.color, isNot(review.labelStyle?.color));
    await tester.tap(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/review')));
    await tester.pumpAndSettle();
    final focused = tester.widget<ChoiceChip>(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/review')));
    expect(focused.selected, isTrue);
    expect(focused.selectedColor, isNotNull);
    expect(focused.labelStyle?.color, review.labelStyle?.color);
  });

  testWidgets('displays actual HEAD and named branch labels', (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands()));
    await tester.pumpAndSettle();
    expect(find.text('Editing: Main path'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-1')), findsOneWidget);
    // The visual history track is drawn next to the existing action card;
    // graph rendering must not remove the accessible commit information.
    expect(find.byKey(const ValueKey('history-rail-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-ref-menu-refs/heads/main')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-head-status')), findsOneWidget);
    expect(find.text('Main path · In use'), findsWidgets);
    expect(find.textContaining('current branch'), findsNothing);
    expect(find.text('main'), findsNothing);
    expect(find.byKey(const ValueKey('history-legend')), findsOneWidget);
    expect(find.text('Earlier points'), findsOneWidget);
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
    expect(find.text('Main path'), findsWidgets);
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
    await tester.tap(find.text('Bookmark this point'));
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

  testWidgets('new branch appears in picker and focuses its history without checkout',
      (tester) async {
    final fake = _forkedCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-node-menu-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch from this point'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'my-new-branch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fake.refs.any((ref) => ref.name == 'refs/heads/my-new-branch' &&
        ref.targetCheckpointId == 4), isTrue);
    expect(find.text('Showing my-new-branch · 3 points'), findsOneWidget);
    expect(find.textContaining('Branch "my-new-branch" created.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-3')), findsNothing);
    expect(find.text('Editing: Main path'), findsOneWidget);
    expect(fake.lastExpectedHeadId, isNull);

    // Viewing a branch and moving the editor HEAD are separate actions.
    await tester.tap(find.byKey(
        const ValueKey('history-switch-selected-branch')));
    await tester.pumpAndSettle();
    expect(find.text('Switch to this path?'), findsOneWidget);
    await tester.tap(find.text('Switch path').last);
    await tester.pumpAndSettle();
    expect(fake.lastExpectedHeadId, 3);
    expect(fake.lastExpectedTipId, 4);

    await tester.tap(find.byKey(const ValueKey('history-branch-picker')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PopupMenuItem<String>, 'my-new-branch'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'All branches'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-commit-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-filter-status')), findsNothing);
  });

  testWidgets('invalid branch name stays in dialog and explains allowed names',
      (tester) async {
    final fake = FakeHistoryCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-node-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch from this point'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'My New Branch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('hyphens or underscores instead of spaces'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('history-ref-name')), findsOneWidget);
    expect(fake.refs, hasLength(2));

    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'my-new-branch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.refs.any((ref) => ref.name == 'refs/heads/my-new-branch'),
        isTrue);
    expect(find.text('Showing my-new-branch · 1 point'), findsOneWidget);
  });

  testWidgets('storage rejection is visible within the history panel',
      (tester) async {
    final fake = FakeHistoryCommands()..rejectBranchCreation = true;
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('history-node-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch from this point'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('history-ref-name')),
        'review');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('history-operation-feedback')),
        findsOneWidget);
    expect(find.textContaining('that name is already in use'), findsOneWidget);
    expect(fake.refs, hasLength(2));
    expect(find.text('Editing: Main path'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-dismiss-feedback')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-operation-feedback')),
        findsNothing);
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
    await tester.tap(find.text('Restore this point'));
    await tester.pumpAndSettle();
    expect(find.textContaining('on a separate editing path'), findsOneWidget);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(find.textContaining('History changed before the restore'), findsOneWidget);
    expect(find.text('Editing: Main path'), findsOneWidget);
  });


  testWidgets('detached history explains that no branch is selected',
      (tester) async {
    await tester.pumpWidget(_host(FakeHistoryCommands(detached: true)));
    await tester.pumpAndSettle();
    expect(find.text('Editing from point #1 · Separate branch'), findsOneWidget);
    expect(find.text('Editing: Main path'), findsNothing);
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
    expect(find.text('Switch to this path'), findsOneWidget);
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
    await tester.tap(find.text('Restore bookmarked point'));
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
    await tester.tap(find.text('Switch to this path'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open the saved subtitles from "Main path"'),
        findsOneWidget);
    await tester.tap(find.text('Switch path').last);
    await tester.pumpAndSettle();

    expect(fake.lastExpectedHeadId, 1);
    expect(fake.lastExpectedTipId, 1);
    expect(find.text('Editing: Main path'), findsOneWidget);
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
    expect(find.text('Branches & bookmarks'), findsOneWidget);
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
    expect(find.text('Switch to this path'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Branches & bookmarks'));
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
    expect(find.text('Editing: Main path'), findsOneWidget);
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

  testWidgets('branch chips use different colors and filter sibling commits',
      (tester) async {
    await tester.pumpWidget(_host(_forkedCommands()));
    await tester.pumpAndSettle();

    final mainChip = tester.widget<ChoiceChip>(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/main')));
    final reviewChip = tester.widget<ChoiceChip>(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/review')));
    final mainColor = (mainChip.avatar! as Icon).color;
    final reviewColor = (reviewChip.avatar! as Icon).color;
    expect(mainColor, isNot(reviewColor));
    final mainRail = tester.widget<CustomPaint>(find.byKey(
        const ValueKey('history-rail-3'))).painter!
        as CheckpointHistoryRailPainter;
    final reviewRail = tester.widget<CustomPaint>(find.byKey(
        const ValueKey('history-rail-4'))).painter!
        as CheckpointHistoryRailPainter;
    expect(mainRail.markerColor, mainColor);
    expect(reviewRail.markerColor, reviewColor);

    await tester.tap(find.byKey(
        const ValueKey('history-branch-filter-refs/heads/review')));
    await tester.pumpAndSettle();
    expect(find.text('Showing review · 3 points'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('history-show-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-commit-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-filter-status')), findsNothing);
  });

  testWidgets('manager path tap filters without restoring HEAD',
      (tester) async {
    final fake = _forkedCommands();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-manage-references')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('history-manage-refs/heads/review')));
    await tester.pumpAndSettle();

    expect(find.text('Showing review · 3 points'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-3')), findsNothing);
    expect(fake.lastExpectedHeadId, isNull);
    expect(fake.refs[0].targetCheckpointId, 3);
  });

  testWidgets('many branches retain usable cards at 320 pixels',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fake = FakeHistoryCommands(additionalCheckpoints: [
      for (var id = 2; id <= 13; id++)
        _childPoint(id, 1, active: id == 2),
    ]);
    fake.checkpoint.isActive = false;
    fake.refs[0].targetCheckpointId = 2;
    fake.refs[1].targetCheckpointId = 2;
    for (var id = 3; id <= 13; id++) {
      fake.refs.add(FakeHistoryCommands._ref(
          'refs/heads/path-$id', 'branch', id));
    }

    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final painter = tester.widget<CustomPaint>(find.byKey(
        const ValueKey('history-rail-13'))).painter!
        as CheckpointHistoryRailPainter;
    expect(CheckpointHistoryRailPainter.railWidth(painter.laneCount), 80);
    final mainFilter = find.byKey(
        const ValueKey('history-branch-filter-refs/heads/main'));
    await tester.ensureVisible(mainFilter);
    await tester.pumpAndSettle();
    await tester.tap(mainFilter);
    await tester.pumpAndSettle();
    expect(find.text('Showing Main path · 2 points'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-13')), findsNothing);

    // Even branches far outside the horizontal chip strip remain selectable.
    await tester.tap(find.byKey(const ValueKey('history-branch-picker')));
    await tester.pumpAndSettle();
    final lastBranch = find.byWidgetPredicate((widget) =>
        widget is PopupMenuItem<String> &&
        widget.value == 'refs/heads/path-13');
    await tester.ensureVisible(lastBranch);
    await tester.pumpAndSettle();
    await tester.tap(lastBranch);
    await tester.pumpAndSettle();
    expect(find.text('Showing path-13 · 2 points'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-13')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-commit-2')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
