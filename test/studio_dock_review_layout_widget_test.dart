import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_bulk_review_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Size size = const Size(1680, 1000),
    ThemeData? theme,
    Future<StudioDockCueUpdate?> Function(
        List<int>, StudioDockReviewAction, int)? review,
    Future<bool> Function(int, String)? applyText,
    Future<bool> Function(int, String, String)? applyTiming,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: theme ?? ThemeData.dark(),
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

  testWidgets('compact subtitle rows use adaptive light-theme backgrounds',
      (tester) async {
    final lightTheme = ThemeData.light();
    await launch(tester, theme: lightTheme);
    final first = find.byKey(const ValueKey('desktop-cue-1'));
    final second = find.byKey(const ValueKey('desktop-cue-2'));
    expect(tester.getSize(first).height, 28);
    expect(tester.getSize(second).height, 28);
    final firstText = tester.widget<Text>(find.descendant(
      of: first, matching: find.text('First original'),
    ));
    expect(firstText.style?.fontSize, 13);
    final rowMaterial = tester.widget<Material>(find.ancestor(
      of: second, matching: find.byType(Material),
    ).first);
    expect(rowMaterial.color, lightTheme.colorScheme.surfaceContainerLow);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multi-cue mark/unmark confirms and retains selection',
      (tester) async {
    final calls = <(List<int>, StudioDockReviewAction, int)>[];
    await launch(tester, review: (ids, action, selected) async {
      calls.add((List<int>.from(ids), action, selected));
      final marked = action == StudioDockReviewAction.mark;
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
    expect(calls.first.$2, StudioDockReviewAction.mark);

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
    expect(calls.last.$2, StudioDockReviewAction.unmark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolve and reopen selected reviews keep marks and notes',
      (tester) async {
    final calls = <StudioDockReviewAction>[];
    var resolved = false;
    await launch(tester, review: (ids, action, selected) async {
      calls.add(action);
      resolved = action == StudioDockReviewAction.resolve;
      return StudioDockCueUpdate(
        selectedCueId: selected,
        selectedCueIds: ids,
        cues: [
          StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First original',
            edited: 'First edited', marked: true,
            comment: 'Needs review', resolved: resolved),
          StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'Second original',
            edited: 'Second edited', marked: true, resolved: resolved),
        ],
      );
    });
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve selected'));
    await tester.pumpAndSettle();
    expect(find.text('Resolve selected subtitles?'), findsOneWidget);
    expect(find.textContaining('Unmarked subtitles will also be marked'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-confirm')));
    await tester.pumpAndSettle();
    expect(calls, [StudioDockReviewAction.resolve]);
    expect(find.byTooltip('Review resolved'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('studio-review-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unresolved').last);
    await tester.pumpAndSettle();
    expect(find.text('No matching subtitle lines'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-bulk-review-confirm')));
    await tester.pumpAndSettle();
    expect(calls, [StudioDockReviewAction.resolve,
        StudioDockReviewAction.reopen]);
    expect(find.byTooltip('Needs review'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review filter Cancel leaves an unsaved cue draft and filter intact',
      (tester) async {
    var saved = 0;
    await launch(tester, applyText: (_, __) async { saved++; return true; });
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Not yet saved');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('studio-review-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unresolved').last);
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final filter = tester.widget<DropdownButton>(
        find.byKey(const ValueKey('studio-review-filter')));
    expect(filter.value.toString(), contains('all'));
    expect(find.text('Not yet saved'), findsWidgets);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(saved, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review filter Apply persists the draft before hiding rows',
      (tester) async {
    final saved = <String>[];
    await launch(tester, applyText: (id, value) async {
      saved.add('$id:$value');
      return true;
    });
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Committed review');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('studio-review-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marked').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Apply')));
    await tester.pumpAndSettle();

    expect(saved, ['1:Committed review']);
    expect(tester.widget<DropdownButton>(
        find.byKey(const ValueKey('studio-review-filter')))
        .value.toString(), contains('marked'));
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed review-filter Apply keeps the original filter and draft',
      (tester) async {
    await launch(tester, applyText: (_, __) async => false);
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Conflicted edit');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-review-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marked').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.widget<DropdownButton>(
        find.byKey(const ValueKey('studio-review-filter')))
        .value.toString(), contains('all'));
    expect(find.text('Conflicted edit'), findsWidgets);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tools Show marked lines shares mobile review navigation',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('studio-tools-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show marked lines'));
    await tester.pumpAndSettle();

    expect(tester.widget<DropdownButton>(
        find.byKey(const ValueKey('studio-review-filter')))
        .value.toString(), contains('marked'));
    expect(find.byKey(const ValueKey('desktop-cue-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsNothing);
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
