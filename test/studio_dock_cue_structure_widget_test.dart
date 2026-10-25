import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_insert_cue_dialog.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_split_cue_dialog.dart';

const _first = StudioDockCue(
  id: 1,
  start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original 1', edited: 'Edit 1',
);
const _second = StudioDockCue(
  id: 2,
  start: '00:00:03,000', end: '00:00:04,000',
  original: 'Original 2', edited: 'Edit 2',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    List<StudioDockCue> cues = const [_first],
    Future<StudioDockCueUpdate?> Function(int?, StudioDockNewCueDraft)? insert,
    Future<StudioDockCueUpdate?> Function(int)? delete,
    Future<StudioDockCueUpdate?> Function(int, StudioDockSplitCueDraft)? split,
    Future<StudioDockCueUpdate?> Function(int, bool)? merge,
    Future<bool> Function(int, String)? applyText,
    bool isEditMode = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        isEditMode: isEditMode,
        initialCues: cues,
        onInsertCue: insert,
        onDeleteCue: delete,
        onSplitCue: split,
        onMergeCue: merge,
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
      return const StudioDockCueUpdate(
        cues: [_first, _second], selectedCueId: 2);
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-insert-cue')));
    await tester.pumpAndSettle();
    expect(find.text('Insert subtitle line'), findsOneWidget);
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

  testWidgets('scratch Edit Mode inserts a single subtitle text field',
      (tester) async {
    StudioDockNewCueDraft? submitted;
    await launch(tester, cues: const [], isEditMode: true,
      insert: (_, draft) async {
        submitted = draft;
        return const StudioDockCueUpdate(cues: [StudioDockCue(
          id: 1, start: '00:00:00,000', end: '00:00:02,000',
          original: '', edited: 'Hello from scratch',
        )], selectedCueId: 1);
      });
    await tester.tap(find.byKey(const ValueKey('studio-empty-create-cue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-insert-original')), findsNothing);
    expect(find.text('Subtitle Text'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('studio-insert-edited')),
        'Hello from scratch');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-insert')));
    await tester.pumpAndSettle();
    expect(submitted?.original, isEmpty);
    expect(submitted?.edited, 'Hello from scratch');
    expect(find.text('SUBTITLE TEXT'), findsWidgets);
    expect(find.text('ORIGINAL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scratch Edit Mode splits subtitle text without translation fields',
      (tester) async {
    StudioDockSplitCueDraft? submitted;
    await launch(tester, isEditMode: true,
      cues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:03,000',
        original: '', edited: 'First second',
      )],
      split: (_, draft) async {
        submitted = draft;
        return const StudioDockCueUpdate(cues: [_first, _second],
            selectedCueId: 1);
      });
    await tester.tap(find.byKey(const ValueKey('studio-dock-split-cue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-split-first-original')),
        findsNothing);
    expect(find.byKey(const ValueKey('studio-split-second-original')),
        findsNothing);
    expect(find.text('Subtitle Text'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('studio-confirm-split')));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!.firstOriginal, isEmpty);
    expect(submitted!.secondOriginal, isEmpty);
    expect(submitted!.firstEdited, 'First');
    expect(submitted!.secondEdited, 'second');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed insert keeps draft open and retries without data loss',
      (tester) async {
    var attempts = 0;
    await launch(tester, insert: (_, draft) async {
      attempts++;
      if (attempts == 1) return null;
      expect(draft.original, 'Retained draft');
      return const StudioDockCueUpdate(
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
        return const StudioDockCueUpdate(
          cues: [StudioDockCue(
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
        return const StudioDockCueUpdate(cues: [_first], selectedCueId: 1);
      },
    );
    expect(find.text('This project has no subtitle lines yet.'), findsOneWidget);
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

  testWidgets('Split validates time, retains rejected draft and refreshes cues',
      (tester) async {
    final attempts = <StudioDockSplitCueDraft>[];
    await launch(tester, split: (number, draft) async {
      expect(number, 1);
      attempts.add(draft);
      if (attempts.length == 1) return null;
      return const StudioDockCueUpdate(cues: [_first, _second], selectedCueId: 1);
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-split-cue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-split-at')),
      '00:00:02,000');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-split')));
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-split-error')), findsOneWidget);
    expect(attempts, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('studio-split-at')),
      '00:00:01,500');
    await tester.enterText(
      find.byKey(const ValueKey('studio-split-second-original')),
      'Important second half');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-split')));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Important second half'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-split-error')), findsOneWidget);
    expect(attempts.length, 1);
    await tester.tap(find.byKey(const ValueKey('studio-confirm-split')));
    await tester.pumpAndSettle();
    expect(attempts.length, 2);
    expect(attempts.last.secondOriginal, 'Important second half');
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Split cancellation does not call persistence callback',
      (tester) async {
    var calls = 0;
    await launch(tester, split: (_, __) async {
      calls++;
      return null;
    });
    await tester.tap(find.byKey(const ValueKey('studio-dock-split-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('Merge chooses neighbor and refreshes selected row only on success',
      (tester) async {
    final requests = <String>[];
    await launch(tester,
      cues: const [_first, _second],
      merge: (cue, previous) async {
        requests.add('$cue:$previous');
        return const StudioDockCueUpdate(
          cues: [StudioDockCue(
            id: 1, start: '00:00:01,000', end: '00:00:04,000',
            original: 'Original 1\nOriginal 2', edited: 'Edit 1\nEdit 2',
          )], selectedCueId: 1);
      },
    );
    await tester.tap(find.byKey(const ValueKey('studio-dock-merge-cue')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(
      const ValueKey('studio-merge-previous'))).onPressed, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    await tester.tap(find.byKey(const ValueKey('studio-dock-merge-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-merge-next')));
    await tester.pumpAndSettle();
    expect(requests, ['1:false']);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsNothing);
    expect(find.text('Original 1\nOriginal 2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dirty inspector draft blocks Split and Merge', (tester) async {
    var calls = 0;
    await launch(tester,
      cues: const [_first, _second],
      applyText: (_, __) async => true,
      split: (_, __) async { calls++; return null; },
      merge: (_, __) async { calls++; return null; },
    );
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
      'Unsaved edit');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-split-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Split subtitle cue #1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('studio-dock-merge-cue')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Combine subtitle cue #1'), findsNothing);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
