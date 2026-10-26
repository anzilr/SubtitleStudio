import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<bool> Function(int, String)? applyText,
    Future<bool> Function(int, String)? applyOriginal,
    Future<StudioDockCueUpdate?> Function(int, String?, bool, bool)? applyNotes,
    Future<StudioDockCueUpdate?> Function(int, String, Map<String, dynamic>)?
        applyEffect,
    Future<bool> Function(String)? changeEncoding,
    Future<List<String>> Function()? loadEncodings,
    String? encoding,
    Future<void> Function(int)? openMarkedLines,
    Future<void> Function()? openProjectSettings,
    bool isEditMode = false,
    int maxLineLength = 32,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      isEditMode: isEditMode,
      maxLineLength: maxLineLength,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited line',
      )],
      onApplyCueText: applyText,
      onApplyCueOriginal: applyOriginal,
      onApplyCueNotes: applyNotes,
      onApplyEffect: applyEffect,
      encoding: encoding,
      onChangeEncoding: changeEncoding,
      onLoadEncodings: loadEncodings,
      onOpenMarkedLines: openMarkedLines,
      onOpenProjectSettings: openProjectSettings,
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
    expect(find.byKey(const ValueKey('studio-original-char-count')),
        findsNothing);
    expect(find.byKey(const ValueKey('studio-edited-char-count')),
        findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Fresh subtitle');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(applied, ['Fresh subtitle']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('line inspector shows the same counters as mobile, live',
      (tester) async {
    await launch(tester, maxLineLength: 10,
        applyText: (_, __) async => true,
        applyOriginal: (_, __) async => true);

    final original = find.byKey(const ValueKey('studio-original-char-count'));
    final edited = find.byKey(const ValueKey('studio-edited-char-count'));
    expect(original, findsOneWidget);
    expect(edited, findsOneWidget);
    expect(find.descendant(of: original, matching: find.text('8 chars')),
        findsOneWidget);
    expect(find.descendant(of: edited, matching: find.text('11 chars')),
        findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Hello  <b>world</b>');
    await tester.pump();
    final editedText = tester.widget<Text>(find.descendant(
      of: edited, matching: find.text('12 chars'),
    ));
    expect(editedText.style!.fontWeight, FontWeight.bold);

    await tester.tap(find.byKey(const ValueKey('studio-original-edit-toggle')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('studio-original-1-0')),
        'New<br>source');
    await tester.pump();
    expect(find.descendant(of: original, matching: find.text('10 chars')),
        findsOneWidget);
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

  testWidgets('Edited Text formatting uses the guarded Text Apply',
      (tester) async {
    final edits = <String>[];
    await launch(tester, applyText: (_, value) async {
      edits.add(value);
      return true;
    });
    await tester.tap(find.byKey(const ValueKey('studio-style-b')));
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-style-u')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-style-clear')), findsOneWidget);
    final apply = find.byKey(const ValueKey('studio-apply-cue'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(edits, ['<b>Edited line</b>']);
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline buttons format only the selected edited substring',
      (tester) async {
    final edits = <String>[];
    await launch(tester, applyText: (_, value) async {
      edits.add(value);
      return true;
    });
    final field = find.byKey(const ValueKey('studio-edit-1-0'));
    await tester.tap(field);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.descendant(
      of: field, matching: find.byType(EditableText)));
    editable.controller.selection = const TextSelection(
        baseOffset: 0, extentOffset: 6);
    await tester.tap(find.byKey(const ValueKey('studio-style-b')));
    await tester.pump();
    expect(editable.controller.text, '<b>Edited</b> line');
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(edits, ['<b>Edited</b> line']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('original text selection stays scoped after toolbar focus change',
      (tester) async {
    await launch(tester, applyText: (_, __) async => true,
        applyOriginal: (_, __) async => true);
    await tester.tap(find.byKey(const ValueKey('studio-original-edit-toggle')));
    await tester.pump();
    final field = find.byKey(const ValueKey('studio-original-1-0'));
    await tester.tap(field);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.descendant(
      of: field, matching: find.byType(EditableText)));
    editable.controller.selection = const TextSelection(
        baseOffset: 0, extentOffset: 8);
    await tester.tap(find.byKey(const ValueKey('studio-style-i')));
    await tester.pump();
    expect(editable.controller.text, '<i>Original</i>');
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear formatting edits the selected portion only',
      (tester) async {
    await launch(tester, applyText: (_, __) async => true);
    final field = find.byKey(const ValueKey('studio-edit-1-0'));
    await tester.tap(field);
    await tester.pump();
    final controller = tester.widget<EditableText>(find.descendant(
      of: field, matching: find.byType(EditableText))).controller;
    controller.value = const TextEditingValue(
        text: '<b>Edited</b> <i>line</i>',
        selection: TextSelection(baseOffset: 14, extentOffset: 25));
    await tester.tap(find.byKey(const ValueKey('studio-style-clear')));
    await tester.pump();
    expect(controller.text, '<b>Edited</b> line');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Style 9-grid uses guarded Apply', (tester) async {
    final edits = <String>[];
    await launch(tester, applyText: (_, text) async {
      edits.add(text);
      return true;
    });
    await tab(tester, 'Style');
    expect(find.byKey(const ValueKey('studio-style-b')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('studio-style-align-8')));
    await tester.pump();
    final apply = find.byKey(const ValueKey('studio-apply-style'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(edits, [r'{\an8}Edited line']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edited Text exposes shared color picker without immediate write',
      (tester) async {
    var calls = 0;
    await launch(tester, applyText: (_, __) async {
      calls++;
      return true;
    });
    await tester.tap(find.byKey(const ValueKey('studio-style-color')));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle text color'), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-style-color-confirm')),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('Style effects reuses mobile sheet and commits returned cues',
      (tester) async {
    final effects = <String>[];
    await launch(tester, applyText: (_, __) async => true,
        applyEffect: (id, type, config) async {
      effects.add(type);
      expect(id, 1);
      expect(config['color'], isA<String>());
      expect(config['endDelay'], isA<num>());
      return const StudioDockCueUpdate(cues: [
        StudioDockCue(id: 1, start: '00:00:01,000', end: '00:00:01,500',
            original: 'Original', edited: 'Effect 1'),
        StudioDockCue(id: 2, start: '00:00:01,500', end: '00:00:02,000',
            original: 'Original', edited: 'Effect 2'),
      ], selectedCueId: 1);
    });
    await tab(tester, 'Style');
    final add = find.byKey(const ValueKey('studio-add-effects'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-effects-sheet')), findsOneWidget);
    expect(find.textContaining('beta feature'), findsWidgets);
    expect(effects, isEmpty);
    final apply = find.text('Apply').last;
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(effects, ['karaoke']);
    expect(find.byKey(const ValueKey('studio-effects-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Effect rejection preserves the beta dialog and cues',
      (tester) async {
    var attempts = 0;
    await launch(tester, applyText: (_, __) async => true,
        applyEffect: (_, __, ___) async {
      attempts++;
      return null;
    });
    await tab(tester, 'Style');
    final add = find.byKey(const ValueKey('studio-add-effects'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    final apply = find.text('Apply').last;
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byKey(const ValueKey('studio-effects-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cue-2')), findsNothing);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-effects-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Status encoding opens an anchored dropdown and persists selection',
      (tester) async {
    final requests = <String>[];
    await launch(tester, encoding: 'UTF-8',
        loadEncodings: () async => ['UTF-8', 'ISO-8859-1'],
        changeEncoding: (value) async {
      requests.add(value);
      return true;
    });
    await tester.tap(find.byKey(const ValueKey('studio-project-encoding')));
    await tester.pumpAndSettle();
    expect(find.text('Project text encoding'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-encoding-ISO-8859-1')));
    await tester.pumpAndSettle();
    expect(requests, ['ISO-8859-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rail offers dictionary and marked/project commands',
      (tester) async {
    var markedOpenedAt = -1;
    var settingsOpened = 0;
    await launch(tester, applyText: (_, __) async => true,
        openMarkedLines: (cue) async { markedOpenedAt = cue; },
        openProjectSettings: () async { settingsOpened++; });
    for (final key in [
      'studio-rail-msone-dictionary', 'studio-rail-olam-dictionary',
      'studio-rail-urban-dictionary', 'studio-rail-marked-lines',
      'studio-rail-project-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-rail-marked-lines')));
    await tester.tap(find.byKey(const ValueKey('studio-rail-marked-lines')));
    await tester.pumpAndSettle();
    expect(markedOpenedAt, 1);
    await tester.ensureVisible(find.byKey(
        const ValueKey('studio-rail-project-settings')));
    await tester.tap(find.byKey(const ValueKey('studio-rail-project-settings')));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(tester.takeException(), isNull);
  });
}
