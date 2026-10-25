import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    required Future<bool> Function(int, String) apply,
    Future<bool> Function(int, String)? applyOriginal,
    Future<bool> Function(int, String, String)? applyTiming,
    Future<bool> Function(int, String, String, String)? applyCombined,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        onApplyCueText: apply,
        onApplyCueOriginal: applyOriginal,
        onApplyCueTiming: applyTiming,
        onApplyCueTextAndTiming: applyCombined,
        initialCues: const [
          StudioDockCue(
            id: 1, start: '00:00:01,000', end: '00:00:02,000',
            original: 'Original 1', edited: 'Earlier edit',
          ),
          StudioDockCue(
            id: 2, start: '00:00:03,000', end: '00:00:04,000',
            original: 'Original 2', edited: '',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Apply is the only action that invokes persistence callback',
      (tester) async {
    final calls = <String>[];
    await launch(tester, apply: (number, text) async {
      calls.add('$number:$text');
      return true;
    });
    expect(find.text('LIVE · TEXT EDIT'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'New draft');
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(calls, ['1:New draft']);
    expect(find.text('New draft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift+Enter saves current text and advances to next cue',
      (tester) async {
    final edits = <String>[];
    await launch(tester, apply: (cue, content) async {
      edits.add('$cue:$content');
      return true;
    });
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Shift edit');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(edits, ['1:Shift edit']);
    expect(find.byKey(const ValueKey('studio-edit-2-1')), findsOneWidget);
    expect(FocusManager.instance.primaryFocus,
        isNotNull, reason: 'New edited text input should receive focus');
    await tester.testTextInput.enterText('Typed without clicking');
    await tester.pump();
    expect(find.text('Typed without clicking'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift+Enter never advances after rejected save',
      (tester) async {
    await launch(tester, apply: (_, __) async => false);
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Keep this draft');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('studio-edit-2-1')), findsNothing);
    expect(find.text('Keep this draft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Original source can be edited and committed independently',
      (tester) async {
    final sources = <String>[];
    final translations = <String>[];
    await launch(tester,
      apply: (line, value) async {
        translations.add('$line:$value');
        return true;
      },
      applyOriginal: (line, value) async {
        sources.add('$line:$value');
        return true;
      },
    );
    final toggle = find.byKey(const ValueKey('studio-original-edit-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('studio-original-1-0')),
        'Updated original');
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sources, ['1:Updated original']);
    expect(translations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Original text toolbar can paste into live translation draft',
      (tester) async {
    final edits = <String>[];
    await launch(tester, apply: (cue, text) async {
      edits.add('$cue:$text');
      return true;
    });
    final reset = find.byKey(
        const ValueKey('studio-inspector-paste-original'));
    await tester.ensureVisible(reset);
    expect(tester.widget<IconButton>(reset).onPressed, isNotNull);
    expect(find.byKey(const ValueKey('studio-reset-to-original')),
        findsNothing);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Original 1'), findsWidgets);
    expect(edits, isEmpty, reason: 'Reset is a draft until Apply is pressed');
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(edits, ['1:Original 1']);
  });

  testWidgets('dirty cue selection supports Cancel and Discard',
      (tester) async {
    await launch(tester, apply: (_, __) async => true);
    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'Keep this draft');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('desktop-cue-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Discard'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Original 2'), findsWidgets);
    expect(find.text('Keep this draft'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar Import/New cannot bypass unsaved-draft confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var imports = 0;
    var creates = 0;
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        onApplyCueText: (_, __) async => true,
        onImportFile: () => imports++,
        onNewProject: () => creates++,
        initialCues: const [StudioDockCue(
          id: 1, start: '00:00:01,000', end: '00:00:02,000',
          original: 'Original', edited: 'Earlier edit')],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unsaved edit');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-import')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(imports, 0);
    expect(creates, 0);

    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.text('Discard')));
    await tester.pumpAndSettle();
    expect(creates, 1);
    expect(imports, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed Apply retains draft and does not advance selection',
      (tester) async {
    await launch(tester, apply: (_, __) async => false);
    await tester.enterText(
      find.byKey(const ValueKey('studio-edit-1-0')), 'Conflicted draft');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    // Inspect before the transient SnackBar auto-dismisses; pumpAndSettle
    // otherwise advances the full notification lifetime.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Conflicted draft'), findsWidgets);
    expect(find.byKey(const ValueKey('studio-discard-cue')), findsOneWidget);
    expect(find.textContaining('Could not apply this edit'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timing draft validates, persists only on Apply, and updates grid',
      (tester) async {
    final changes = <String>[];
    await launch(tester,
      apply: (_, __) async => true,
      applyTiming: (cue, start, end) async {
        changes.add('$cue:$start->$end');
        return true;
      },
    );
    expect(find.byKey(const ValueKey('inspector-tab-Timing')), findsNothing);
    expect(find.byKey(const ValueKey('inspector-tab-Text')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('studio-timing-start-1-0')),
      '00:00:03,000');
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-timing-error')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(
      const ValueKey('studio-apply-cue'))).onPressed, isNull);
    expect(changes, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('studio-timing-end-1-0')),
      '00:00:04,000');
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-timing-error')), findsNothing);
    expect(changes, isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(changes, ['1:00:00:03,000->00:00:04,000']);
    expect(find.text('00:00:04,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Duration adjusts END and persists the resulting timecode',
      (tester) async {
    final changes = <String>[];
    await launch(tester,
      apply: (_, __) async => true,
      applyTiming: (cue, start, end) async {
        changes.add('$cue:$start->$end');
        return true;
      },
    );
    final duration = find.byKey(
        const ValueKey('studio-timing-duration-1-0-0'));
    await tester.enterText(duration, '2.5');
    await tester.pumpAndSettle();
    expect(find.text('00:00:03,500'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(changes, ['1:00:00:01,000->00:00:03,500']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving Text with a timing draft requires Apply or Discard',
      (tester) async {
    final changes = <String>[];
    await launch(tester,
      apply: (_, __) async => true,
      applyTiming: (cue, start, end) async {
        changes.add('$cue:$start:$end');
        return true;
      },
    );
    await tester.enterText(
      find.byKey(const ValueKey('studio-timing-start-1-0')),
      '00:00:01,250');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('inspector-tab-Notes')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-timing-start-1-0')),
      findsOneWidget);
    expect(changes, isEmpty);

    await tester.tap(find.byKey(const ValueKey('inspector-tab-Notes')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog), matching: find.text('Apply')));
    await tester.pumpAndSettle();
    expect(changes, ['1:00:00:01,250:00:00:02,000']);
    expect(find.text('REVIEW NOTES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Text and Timing changes share one Apply callback and history',
      (tester) async {
    final combined = <String>[];
    var separateText = 0;
    var separateTime = 0;
    await launch(tester,
      apply: (_, __) async { separateText++; return true; },
      applyTiming: (_, __, ___) async { separateTime++; return true; },
      applyCombined: (cue, text, start, end) async {
        combined.add('$cue:$text:$start:$end');
        return true;
      },
    );
    expect(find.byKey(const ValueKey('inspector-tab-Timing')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Updated text');
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('studio-timing-start-1-0')),
        '00:00:01,250');
    await tester.pump();
    final apply = find.byKey(const ValueKey('studio-apply-cue'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(combined, ['1:Updated text:00:00:01,250:00:00:02,000']);
    expect(separateText, 0);
    expect(separateTime, 0);
    expect(find.text('Updated text'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
