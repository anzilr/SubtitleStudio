import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<bool> Function(int, String)? applyText,
    Future<StudioDockCueUpdate?> Function(int, String?, bool, bool)? applyNotes,
    bool isEditMode = false,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      isEditMode: isEditMode,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited line',
      )],
      onApplyCueText: applyText,
      onApplyCueNotes: applyNotes,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Edit Mode only displays the subtitle text editor',
      (tester) async {
    final applied = <String>[];
    await launch(tester, isEditMode: true, applyText: (_, text) async {
      applied.add(text);
      return true;
    });
    expect(find.text('SUBTITLE TEXT'), findsWidgets);
    expect(find.text('ORIGINAL TEXT'), findsNothing);
    expect(find.text('Reset to original'), findsNothing);
    expect(find.text('EDITED'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Fresh subtitle');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(applied, ['Fresh subtitle']);
    expect(tester.takeException(), isNull);
  });

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(ValueKey('inspector-tab-$label')));
    await tester.pumpAndSettle();
  }

  testWidgets('Notes Apply commits comment, mark and resolution together',
      (tester) async {
    final calls = <(int, String?, bool, bool)>[];
    await launch(tester, applyNotes: (id, comment, marked, resolved) async {
      calls.add((id, comment, marked, resolved));
      return StudioDockCueUpdate(cues: [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited line',
        comment: comment, marked: marked, resolved: resolved,
      )], selectedCueId: 1);
    });
    await tab(tester, 'Notes');
    await tester.enterText(find.byKey(
        const ValueKey('studio-notes-comment-1-0')), 'Review this text');
    await tester.pump();
    expect(tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('studio-notes-mark'))).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('studio-notes-resolved')));
    await tester.pump();
    final apply = find.byKey(const ValueKey('studio-apply-notes'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(calls, [(1, 'Review this text', true, true)]);
    expect(find.text('Review resolved · mark and comments are kept.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notes draft confirmation Cancel retains; Apply switches tab',
      (tester) async {
    var saves = 0;
    await launch(tester, applyNotes: (id, comment, marked, resolved) async {
      saves++;
      return StudioDockCueUpdate(cues: [StudioDockCue(
        id: id, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited line',
        comment: comment, marked: marked, resolved: resolved,
      )], selectedCueId: id);
    });
    await tab(tester, 'Notes');
    await tester.enterText(find.byKey(
        const ValueKey('studio-notes-comment-1-0')), 'Pending note');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('inspector-tab-Text')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-apply-notes')), findsOneWidget);
    expect(saves, 0);

    await tester.tap(find.byKey(const ValueKey('inspector-tab-Text')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byKey(const ValueKey('studio-apply-notes')), findsNothing);
    await tab(tester, 'Notes');
    expect(find.text('Pending note'), findsOneWidget);
  });

  testWidgets('rejected Notes Apply keeps draft text', (tester) async {
    await launch(tester, applyNotes: (_, __, ___, ____) async => null);
    await tab(tester, 'Notes');
    await tester.enterText(find.byKey(
        const ValueKey('studio-notes-comment-1-0')), 'Do not lose this');
    await tester.pump();
    final apply = find.byKey(const ValueKey('studio-apply-notes'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.textContaining('Your draft is preserved'), findsOneWidget);
    expect(tester.widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('studio-notes-comment-1-0')),
      matching: find.byType(EditableText),
    )).controller.text, 'Do not lose this');
  });

  testWidgets('Style formatting and 9-grid use the guarded Text Apply',
      (tester) async {
    final edits = <String>[];
    await launch(tester, applyText: (_, value) async {
      edits.add(value);
      return true;
    });
    await tab(tester, 'Style');
    await tester.tap(find.byKey(const ValueKey('studio-style-b')));
    await tester.pump();
    expect(find.textContaining('<b>Edited line</b>'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('studio-style-align-8')));
    await tester.pump();
    final apply = find.byKey(const ValueKey('studio-apply-style'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(edits, [r'{\an8}<b>Edited line</b>']);
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Style tab exposes shared color picker without immediate write',
      (tester) async {
    var calls = 0;
    await launch(tester, applyText: (_, __) async {
      calls++;
      return true;
    });
    await tab(tester, 'Style');
    await tester.tap(find.byKey(const ValueKey('studio-style-color')));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle text color'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-style-color-confirm')),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });
}
