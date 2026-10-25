import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final manager = MSoneHotkeyManager.instance;

  Future<void> launch(WidgetTester tester, {
    GlobalKey<StudioDockWorkspaceState>? dockKey,
    StudioDockPlaybackLink? playback,
    VoidCallback? onPlay,
    Future<StudioDockFileResult> Function()? onSaveProject,
    Future<void> Function()? onHelp,
    Future<void> Function()? onSettings,
    Future<StudioDockCueUpdate?> Function(
      int, String?, bool, bool)? onNotes,
    Future<bool> Function(int, String)? onText,
    Future<bool> Function(int, String, String)? onTiming,
    bool isEditMode = false,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      key: dockKey,
      manageLiveHotkeys: true,
      isLiveSession: true,
      isEditMode: isEditMode,
      initialCues: const [
        StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'First', edited: 'First translated'),
        StudioDockCue(id: 2, start: '00:00:03,000',
            end: '00:00:04,000', original: 'Second', edited: ''),
      ],
      playback: playback,
      onTogglePlayback: onPlay,
      onSaveProject: onSaveProject,
      onOpenHelp: onHelp,
      onOpenAppSettings: onSettings,
      onApplyCueNotes: onNotes,
      onApplyCueText: onText,
      onApplyCueTiming: onTiming,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Live play and save project callbacks use the shared manager',
      (tester) async {
    var toggles = 0;
    var saves = 0;
    await launch(tester,
      onPlay: () => toggles++,
      onSaveProject: () async {
        saves++;
        return StudioDockFileResult.saved;
      },
    );
    expect(manager.dispatchForTesting(HotkeyAction.playPause), isTrue);
    expect(manager.dispatchForTesting(HotkeyAction.saveProject), isTrue);
    await tester.pumpAndSettle();
    expect(toggles, 1);
    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cue navigation seeks the same mounted playback link',
      (tester) async {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    await launch(tester, playback: link);
    expect(manager.dispatchForTesting(HotkeyAction.nextLine), isTrue);
    await tester.pumpAndSettle();
    expect(seeks, [const Duration(seconds: 3)]);
    expect(manager.dispatchForTesting(HotkeyAction.previousLine), isTrue);
    await tester.pumpAndSettle();
    expect(seeks.last, const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    link.dispose();
  });

  testWidgets('Shortcuts never act behind a modal dialog', (tester) async {
    var helpCalls = 0;
    final dock = GlobalKey<StudioDockWorkspaceState>();
    await launch(tester, dockKey: dock, onHelp: () async { helpCalls++; });
    showDialog<void>(
      context: dock.currentContext!,
      builder: (dialog) => AlertDialog(
        title: const Text('Modal shortcut guard'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'))],
      ),
    );
    await tester.pumpAndSettle();
    expect(manager.dispatchForTesting(HotkeyAction.help), isTrue);
    await tester.pumpAndSettle();
    expect(helpCalls, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(manager.dispatchForTesting(HotkeyAction.help), isTrue);
    await tester.pumpAndSettle();
    expect(helpCalls, 1);
  });

  testWidgets('Copy is Flutter-scoped and native cue hotkeys respect text focus',
      (tester) async {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    await launch(tester, playback: link, onText: (_, __) async => true);
    // Native manager never registers Copy: EditableText retains Ctrl/Cmd+C,
    // while the parent CallbackShortcuts owns copy of selected cue rows.
    expect(manager.dispatchForTesting(HotkeyAction.copy), isFalse);
    final shortcuts = tester.widget<CallbackShortcuts>(
        find.byType(CallbackShortcuts).first);
    expect(shortcuts.bindings.containsKey(
        const SingleActivator(LogicalKeyboardKey.keyC, control: true)), isTrue);
    expect(shortcuts.bindings.containsKey(
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true)), isTrue);

    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')),
        'Editing this subtitle');
    await tester.pump();
    expect(manager.dispatchForTesting(HotkeyAction.nextLine), isTrue);
    await tester.pump();
    expect(seeks, isEmpty);
    expect(find.text('Editing this subtitle'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    link.dispose();
  });

  testWidgets('Ctrl+Shift+M drafts a review mark instead of persisting it',
      (tester) async {
    var persisted = 0;
    await launch(tester, onNotes: (id, note, marked, resolved) async {
      persisted++;
      return null;
    });
    expect(manager.dispatchForTesting(HotkeyAction.markLineAndComment), isTrue);
    await tester.pumpAndSettle();
    expect(persisted, 0);
    expect(tester.widget<FilledButton>(
        find.byKey(const ValueKey('studio-apply-notes'))).onPressed,
        isNotNull);
    expect(tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('studio-notes-mark'))).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Help/Settings mapping honors missing optional host actions',
      (tester) async {
    var help = 0;
    await launch(tester, onHelp: () async { help++; });
    expect(manager.dispatchForTesting(HotkeyAction.help), isTrue);
    expect(manager.dispatchForTesting(HotkeyAction.settings), isFalse);
    await tester.pumpAndSettle();
    expect(help, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bold and italic change only the live cue draft, not persistence',
      (tester) async {
    final saved = <String>[];
    await launch(tester, onText: (_, text) async {
      saved.add(text);
      return true;
    });
    final input = find.byKey(const ValueKey('studio-edit-1-0'));
    await tester.enterText(input, 'Hello subtitle');
    await tester.pump();
    expect(manager.dispatchForTesting(HotkeyAction.boldFormat), isTrue);
    await tester.pump();
    var editor = tester.widget<EditableText>(find.descendant(
      of: input, matching: find.byType(EditableText)));
    expect(editor.controller.text, '<b>Hello subtitle</b>');

    expect(manager.dispatchForTesting(HotkeyAction.italicFormat), isTrue);
    await tester.pump();
    editor = tester.widget<EditableText>(find.descendant(
      of: input, matching: find.byType(EditableText)));
    expect(editor.controller.text, '<i><b>Hello subtitle</b></i>');
    expect(saved, isEmpty);

    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(saved, ['<i><b>Hello subtitle</b></i>']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Formatting never modifies a focused timecode field',
      (tester) async {
    await launch(tester,
      onText: (_, __) async => true,
      onTiming: (_, __, ___) async => true,
    );
    final timing = find.byKey(const ValueKey('studio-timing-start-1-0'));
    await tester.enterText(timing, '00:00:01,250');
    await tester.pump();
    expect(manager.dispatchForTesting(HotkeyAction.boldFormat), isTrue);
    await tester.pump();
    final timeInput = tester.widget<EditableText>(find.descendant(
      of: timing, matching: find.byType(EditableText)));
    expect(timeInput.controller.text, '00:00:01,250');
    final cueInput = tester.widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('studio-edit-1-0')),
      matching: find.byType(EditableText)));
    expect(cueInput.controller.text, 'First translated');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paste Original is a draft, and is absent from Edit Mode',
      (tester) async {
    final saved = <String>[];
    await launch(tester, onText: (_, text) async {
      saved.add(text);
      return true;
    });
    expect(manager.dispatchForTesting(HotkeyAction.pasteOriginal), isTrue);
    await tester.pump();
    expect(find.byKey(const ValueKey('studio-edit-1-1')), findsOneWidget);
    final editor = tester.widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('studio-edit-1-1')),
      matching: find.byType(EditableText)));
    expect(editor.controller.text, 'First');
    expect(saved, isEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.tap(find.byKey(const ValueKey('studio-apply-cue')));
    await tester.pumpAndSettle();
    expect(saved, ['First']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await launch(tester, onText: (_, __) async => true, isEditMode: true);
    expect(manager.dispatchForTesting(HotkeyAction.pasteOriginal), isFalse);
    expect(find.textContaining('Paste original text'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
