import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const cues = [
    StudioDockCue(id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'First', edited: ''),
    StudioDockCue(id: 2, start: '00:00:03,000', end: '00:00:04,000',
        original: 'Second', edited: ''),
    StudioDockCue(id: 3, start: '00:00:05,000', end: '00:00:06,000',
        original: 'Third', edited: ''),
  ];

  Future<void> launch(WidgetTester tester, {
    Future<StudioDockCueUpdate?> Function(
        List<int>, String, String, int)? shift,
    Future<StudioDockCueUpdate?> Function(List<int>, int)? delete,
    Future<bool> Function(int, String)? edit,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      initialCues: cues,
      isLiveSession: true,
      onShiftSelectedCues: shift,
      onDeleteSelectedCues: delete,
      onApplyCueText: edit,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> openTools(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
  }

  Future<void> tapTool(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> selectSecondAndThird(WidgetTester tester) async {
    await tapTool(tester, 'studio-tool-select-indices');
    await tester.enterText(find.byKey(const ValueKey('studio-range-start')), '2');
    await tester.enterText(find.byKey(const ValueKey('studio-range-end')), '3');
    await tester.tap(find.byKey(const ValueKey('studio-range-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
  }

  testWidgets('Index selection is inclusive and validates reversed ranges',
      (tester) async {
    await launch(tester);
    await openTools(tester);
    await tapTool(tester, 'studio-tool-select-indices');
    await tester.enterText(find.byKey(const ValueKey('studio-range-start')), '3');
    await tester.enterText(find.byKey(const ValueKey('studio-range-end')), '2');
    await tester.tap(find.byKey(const ValueKey('studio-range-confirm')));
    await tester.pump();
    expect(find.textContaining('in order'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('studio-range-start')), '2');
    await tester.tap(find.byKey(const ValueKey('studio-range-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected shift passes exactly chosen cue IDs and anchors',
      (tester) async {
    final calls = <(List<int>, String, String, int)>[];
    await launch(tester, shift: (ids, start, end, selected) async {
      calls.add((ids, start, end, selected));
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First', edited: ''),
        StudioDockCue(id: 2, start: '00:00:04,000',
            end: '00:00:05,000', original: 'Second', edited: ''),
        StudioDockCue(id: 3, start: '00:00:07,000',
            end: '00:00:08,000', original: 'Third', edited: ''),
      ], selectedCueId: 3, selectedCueIds: [2, 3]);
    });
    await openTools(tester);
    await selectSecondAndThird(tester);
    await tapTool(tester, 'studio-tool-shift-selected');
    await tester.enterText(
        find.byKey(const ValueKey('studio-selected-start')), '00:00:04,000');
    await tester.enterText(
        find.byKey(const ValueKey('studio-selected-end')), '00:00:09,000');
    await tester.tap(find.byKey(const ValueKey('studio-selected-shift-apply')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.$1, [2, 3]);
    expect(calls.single.$2, '00:00:04,000');
    expect(calls.single.$3, '00:00:09,000');
    expect(calls.single.$4, 3);
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected delete cancellation writes nothing; confirm once',
      (tester) async {
    final calls = <List<int>>[];
    await launch(tester, delete: (ids, _) async {
      calls.add(ids);
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First', edited: ''),
      ], selectedCueId: 1);
    });
    await openTools(tester);
    await selectSecondAndThird(tester);
    await tapTool(tester, 'studio-tool-delete-selected');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tapTool(tester, 'studio-tool-delete-selected');
    await tester.tap(find.byKey(const ValueKey('studio-confirm-delete-selected')));
    await tester.pumpAndSettle();
    expect(calls, [[2, 3]]);
    expect(find.textContaining('1 of 1 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rejected selected shift preserves the selection and shows error',
      (tester) async {
    await launch(tester, shift: (_, __, ___, ____) async => null);
    await openTools(tester);
    await selectSecondAndThird(tester);
    await tapTool(tester, 'studio-tool-shift-selected');
    await tester.tap(find.byKey(const ValueKey('studio-selected-shift-apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Two pointer taps select an inclusive range in either order',
      (tester) async {
    await launch(tester);
    await openTools(tester);
    await tapTool(tester, 'studio-tool-select-range');
    await tester.tap(find.byKey(const ValueKey('desktop-cue-3')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 3 subtitles selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 of 3 subtitles selected'), findsOneWidget);
    expect(find.text('Range selection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unsaved inspector draft blocks selected index dialog on Cancel',
      (tester) async {
    await launch(tester, edit: (_, __) async => true);
    await openTools(tester);
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unsaved new text');
    await tester.pump();
    await tapTool(tester, 'studio-tool-select-indices');
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-range-start')), findsNothing);
    expect(find.textContaining('1 of 3 subtitles selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
