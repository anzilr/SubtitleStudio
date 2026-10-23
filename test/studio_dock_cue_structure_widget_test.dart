import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/desktop_workspace_preview.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_insert_cue_dialog.dart';

const _first = WorkspaceDemoCue(
  id: 1,
  start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original 1', edited: 'Edit 1',
);
const _second = WorkspaceDemoCue(
  id: 2,
  start: '00:00:03,000', end: '00:00:04,000',
  original: 'Original 2', edited: 'Edit 2',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    List<WorkspaceDemoCue> cues = const [_first],
    Future<WorkspaceCueUpdate?> Function(int?, StudioDockNewCueDraft)? insert,
    Future<WorkspaceCueUpdate?> Function(int)? delete,
    Future<bool> Function(int, String)? applyText,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: DesktopWorkspacePreview(
        liveReadOnly: true,
        initialCues: cues,
        onInsertCue: insert,
        onDeleteCue: delete,
        onApplyCueText: applyText,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Insert validates input and saves only after confirmation',
      (tester) async {
    final attempts = <String>[];
    await launch(tester, insert: (after, draft) async {
      attempts.add('$after:${draft.start}:${draft.original}');
      return const WorkspaceCueUpdate(
        cues: [_first, _second], selectedCueId: 2);
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-insert-cue')));
    await tester.pumpAndSettle();
    expect(find.text('Insert subtitle cue'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(attempts, isEmpty);

    await tester.tap(find.byKey(const ValueKey('studio-dock-insert-cue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-insert-end')),
      '00:00:01,000');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-insert-error')), findsOneWidget);
    expect(attempts, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('studio-insert-end')),
      '00:00:04,000');
    await tester.enterText(find.byKey(const ValueKey('studio-insert-original')),
      'New source');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pumpAndSettle();
    expect(attempts, ['1:00:00:02,000:New source']);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed insert keeps draft open and retries without data loss',
      (tester) async {
    var attempts = 0;
    await launch(tester, insert: (_, draft) async {
      attempts++;
      if (attempts == 1) return null;
      expect(draft.original, 'Retained draft');
      return const WorkspaceCueUpdate(
        cues: [_first, _second], selectedCueId: 2);
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-insert-cue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-insert-original')),
      'Retained draft');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey('studio-insert-error')), findsOneWidget);
    expect(find.text('Retained draft'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
  });

  testWidgets('Delete Cancel is safe; confirm refreshes renumbered cue list',
      (tester) async {
    var deletions = 0;
    await launch(tester,
      cues: const [_first, _second],
      delete: (cue) async {
        deletions++;
        expect(cue, 1);
        return const WorkspaceCueUpdate(
          cues: [WorkspaceDemoCue(
            id: 1, start: '00:00:03,000', end: '00:00:04,000',
            original: 'Original 2', edited: 'Edit 2',
          )], selectedCueId: 1);
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-dock-delete-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletions, 0);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-dock-delete-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-confirm-delete')));
    await tester.pumpAndSettle();
    expect(deletions, 1);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsNothing);
    expect(find.text('Original 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty project can add its first cue without classic Editor',
      (tester) async {
    int? anchor = -1;
    await launch(tester,
      cues: const [],
      insert: (after, draft) async {
        anchor = after;
        return const WorkspaceCueUpdate(cues: [_first], selectedCueId: 1);
      },
    );
    expect(find.text('This project has no subtitle cues yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-empty-create-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pumpAndSettle();
    expect(anchor, isNull);
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
  });

  testWidgets('Dirty text cannot be bypassed by Insert toolbar',
      (tester) async {
    var inserts = 0;
    await launch(tester,
      applyText: (_, __) async => true,
      insert: (_, __) async {
        inserts++;
        return null;
      },
    );
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
      'Unsaved edit');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-insert-cue')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Insert subtitle cue'), findsNothing);
    expect(inserts, 0);
    expect(tester.takeException(), isNull);
  });
}
