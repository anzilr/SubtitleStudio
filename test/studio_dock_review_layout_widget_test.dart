import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Size size = const Size(1680, 1000),
    Future<StudioDockCueUpdate?> Function(List<int>, bool, int)? review,
    Future<bool> Function(int, String)? applyText,
    Future<bool> Function(int, String, String)? applyTiming,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(),
      home: StudioDockWorkspace(
        isLiveSession: true,
        onApplyBulkReview: review,
        onApplyCueText: applyText,
        onApplyCueTiming: applyTiming,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First original',
            edited: 'First edited', marked: true,
            comment: 'Needs review', resolved: true),
          StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'Second original',
            edited: 'Second edited'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('multi-cue mark/unmark confirms and retains selection',
      (tester) async {
    final calls = <(List<int>, bool, int)>[];
    await launch(tester, review: (ids, marked, selected) async {
      calls.add((List<int>.from(ids), marked, selected));
      return StudioDockCueUpdate(
        selectedCueId: selected,
        selectedCueIds: ids,
        cues: [
          StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First original',
            edited: 'First edited', marked: marked,
            comment: marked ? 'Needs review' : null,
            resolved: marked),
          StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'Second original',
            edited: 'Second edited', marked: marked),
        ],
      );
    });

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark selected for review'));
    await tester.pumpAndSettle();
    expect(find.text('Mark selected subtitles?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark selected for review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('studio-bulk-review-confirm')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.first.$1, [1, 2]);
    expect(calls.first.$2, isTrue);

    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unmark selected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('comments and resolved flags'), findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('studio-bulk-review-confirm')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls.last.$1, [1, 2]);
    expect(calls.last.$2, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1100-pixel theme-aware inspector overlays Text and Timing',
      (tester) async {
    await launch(tester,
      size: const Size(1100, 768),
      applyText: (_, __) async => true,
      applyTiming: (_, __, ___) async => true,
    );
    expect(find.byKey(const ValueKey('studio-edit-1-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-inspector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inspector-tab-Text')), findsOneWidget);
    expect(find.byKey(const ValueKey('inspector-tab-Timing')), findsNothing);
    expect(find.byKey(const ValueKey('studio-edit-1-0')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('studio-timing-start-1-0')),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('inspector-page-0')),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.byKey(const ValueKey('studio-timing-start-1-0')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
