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
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      key: dockKey,
      manageLiveHotkeys: true,
      isLiveSession: true,
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

  testWidgets('Copy shortcut respects an active EditableText draft',
      (tester) async {
    await Clipboard.setData(const ClipboardData(text: 'original clipboard'));
    await launch(tester, onText: (_, __) async => true);
    final editor = find.byKey(const ValueKey('studio-edit-1-0'));
    await tester.enterText(editor, 'Editing this subtitle');
    await tester.pump();
    // Copy stays in Flutter's scoped shortcut tree rather than native
    // hotkey_manager, so EditableText keeps its own Ctrl+C semantics.
    expect(manager.dispatchForTesting(HotkeyAction.copy), isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final unchanged = await Clipboard.getData('text/plain');
    expect(unchanged?.text, 'original clipboard');
    expect(tester.takeException(), isNull);
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
}
