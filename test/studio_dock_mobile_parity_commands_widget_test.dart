import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    VoidCallback? fullscreen,
    Future<StudioDockCueUpdate?> Function(int)? deleteCue,
    Future<StudioDockCueUpdate?> Function(List<int>, int)? deleteSelected,
    Future<bool> Function(int, String)? edit,
    bool withVideo = true,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        manageLiveHotkeys: true,
        initialCues: const [
          StudioDockCue(
            id: 1, start: '00:00:01,000', end: '00:00:02,000',
            original: 'First', edited: '', marked: true),
          StudioDockCue(
            id: 2, start: '00:00:03,000', end: '00:00:04,000',
            original: 'Second', edited: ''),
        ],
        videoSurface: withVideo ? const SizedBox(key: ValueKey('fake-video')) : null,
        onToggleFullscreen: fullscreen,
        onDeleteCue: deleteCue,
        onDeleteSelectedCues: deleteSelected,
        onApplyCueText: edit,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Fullscreen action is available through View menu and shared F11 binding',
      (tester) async {
    var toggles = 0;
    await launch(tester, fullscreen: () => toggles++);
    final manager = MSoneHotkeyManager.instance;
    expect(manager.dispatchForTesting(HotkeyAction.toggleFullscreen), isTrue);
    await tester.pumpAndSettle();
    expect(toggles, 1);
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Toggle video fullscreen'), findsOneWidget);
    await tester.tap(find.text('Toggle video fullscreen'));
    await tester.pumpAndSettle();
    expect(toggles, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No attached video disables View fullscreen command',
      (tester) async {
    var toggles = 0;
    await launch(tester, fullscreen: () => toggles++, withVideo: false);
    await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
    await tester.pumpAndSettle();
    // The generic PopupMenuItem type is private to Studio Dock; locating it
    // by the public Text child works reliably in Flutter widget tests.
    final text = find.text('Toggle video fullscreen');
    expect(text, findsOneWidget);
    await tester.tap(text);
    await tester.pumpAndSettle();
    expect(toggles, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(toggles, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fullscreen shortcut cannot fire behind a route or while typing',
      (tester) async {
    var toggles = 0;
    await launch(tester, fullscreen: () => toggles++,
        edit: (_, __) async => true);
    final manager = MSoneHotkeyManager.instance;
    await tester.enterText(find.byKey(const ValueKey('studio-edit-1-0')),
        'Unsaved text');
    await tester.pump();
    expect(manager.dispatchForTesting(HotkeyAction.toggleFullscreen), isTrue);
    await tester.pumpAndSettle();
    expect(toggles, 0);
    // Clear focus without discarding the draft; a modal must still suppress.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final ctx = tester.element(find.byKey(const ValueKey('fake-video')));
    showDialog<void>(context: ctx, builder: (dialog) => AlertDialog(
      title: const Text('Modal'),
      actions: [TextButton(
        onPressed: () => Navigator.of(dialog).pop(),
        child: const Text('Close'),
      )],
    ));
    await tester.pumpAndSettle();
    expect(manager.dispatchForTesting(HotkeyAction.toggleFullscreen), isTrue);
    await tester.pumpAndSettle();
    expect(toggles, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shift+Delete goes through existing guarded single-cue confirmation',
      (tester) async {
    var deletes = 0;
    await launch(tester, deleteCue: (id) async {
      deletes++;
      expect(id, 1);
      return null;
    });
    final manager = MSoneHotkeyManager.instance;
    expect(manager.dispatchForTesting(HotkeyAction.delete), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Delete subtitle cue #1?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Marked-lines hotkey reuses the existing grid review filter',
      (tester) async {
    await launch(tester);
    final manager = MSoneHotkeyManager.instance;
    expect(manager.dispatchForTesting(HotkeyAction.showMarkedLines), isTrue);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton>(
        find.byKey(const ValueKey('studio-review-filter')));
    expect(dropdown.value.toString(), contains('marked'));
    expect(tester.takeException(), isNull);
  });
}
