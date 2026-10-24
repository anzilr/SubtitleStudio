import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_search_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    List<StudioDockSearchHit> Function(String, bool, bool)? search,
    Future<StudioDockCueUpdate?> Function(
        List<StudioDockSearchHit>, String, String, bool)? replace,
    Future<StudioDockCueUpdate?> Function(int, int)? shift,
    Future<StudioDockCueUpdate?> Function(int)? clear,
  }) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      initialCues: const [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'cat cat', edited: ''),
        StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'The cat', edited: ''),
      ],
      isLiveSession: true,
      onFindCues: search,
      onReplaceMatches: replace,
      onShiftAllCues: shift,
      onClearAllFormatting: clear,
    )));
    await tester.pumpAndSettle();
  }

  SubtitleLine line(int index, String text) => SubtitleLine()
    ..index = index
    ..startTime = index == 1 ? '00:00:01,000' : '00:00:03,000'
    ..endTime = index == 1 ? '00:00:02,000' : '00:00:04,000'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;

  testWidgets('Find lists real matches and opens their cue in the editor',
      (tester) async {
    await launch(tester, search: (term, sensitive, whole) =>
        StudioDockSearchService.findLines(
          lines: [line(1, 'cat cat'), line(2, 'The cat')],
          term: term, caseSensitive: sensitive, wholeWord: whole));
    await tester.tap(find.byKey(const ValueKey('rail-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-find-input')), 'cat');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-find-run')));
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-find-hit-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-find-hit-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-find-hit-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-find-section')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Replace selected confirms before invoking guarded callback',
      (tester) async {
    var text = 'cat cat';
    var calls = 0;
    await launch(tester,
      search: (term, sensitive, whole) => StudioDockSearchService.findLines(
        lines: [line(1, text)], term: term,
        caseSensitive: sensitive, wholeWord: whole),
      replace: (hits, term, replacement, sensitive) async {
        calls++;
        expect(hits, hasLength(1));
        expect(term, 'cat');
        expect(replacement, 'dog');
        text = 'dog cat';
        return const StudioDockCueUpdate(cues: [
          StudioDockCue(id: 1, start: '00:00:01,000',
              end: '00:00:02,000', original: 'cat cat', edited: 'dog cat'),
        ], selectedCueId: 1);
      });
    await tester.tap(find.byKey(const ValueKey('rail-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('studio-find-input')), 'cat');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-find-run')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('studio-replace-input')), 'dog');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-find-select-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-replace-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Replace subtitle text?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byKey(const ValueKey('studio-replace-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-replace-confirm')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const ValueKey('studio-find-hit-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools confirm a bulk time shift and preserve project editing',
      (tester) async {
    final shifts = <(int, int)>[];
    await launch(tester, shift: (selected, delta) async {
      shifts.add((selected, delta));
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:00,500',
            end: '00:00:01,500', original: 'cat cat', edited: ''),
        StudioDockCue(id: 2, start: '00:00:02,500',
            end: '00:00:03,500', original: 'The cat', edited: ''),
      ], selectedCueId: 1);
    });
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('studio-tool-shift-input')), '-500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-tool-shift')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(shifts, isEmpty);
    await tester.tap(find.byKey(const ValueKey('studio-tool-shift')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(shifts, [(1, -500)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rejected formatting bulk edit leaves Tools open with error',
      (tester) async {
    await launch(tester, clear: (_) async => null);
    await tester.tap(find.byKey(const ValueKey('rail-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-tool-clear-formatting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-tool-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-tools-section')), findsOneWidget);
    expect(find.textContaining('Could not apply this tool'), findsOneWidget);
  });
}
