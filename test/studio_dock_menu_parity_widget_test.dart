import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester, {
    Future<void> Function()? settings,
    Future<void> Function()? help,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [
        StudioDockCue(
          id: 1, start: '00:00:01,000', end: '00:00:02,000',
          original: 'Original', edited: 'Edited line',
        ),
        StudioDockCue(
          id: 2, start: '00:00:03,000', end: '00:00:04,000',
          original: 'Second original', edited: '', storedEdited: null,
        ),
        StudioDockCue(
          id: 3, start: '00:00:05,000', end: '00:00:06,000',
          original: 'Third original', edited: '', storedEdited: '',
        ),
        StudioDockCue(
          id: 4, start: '00:00:07,000', end: '00:00:08,000',
          original: 'Fourth original', edited: 'Final edit',
          storedEdited: 'Final edit',
        ),
      ],
      onApplyCueText: (_, __) async => true,
      onOpenAppSettings: settings,
      onOpenHelp: help,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester,
      String menuKey, String item) async {
    await tester.tap(find.byKey(ValueKey(menuKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings rail and View menu invoke the shared settings host',
      (tester) async {
    var opens = 0;
    await launch(tester, settings: () async { opens++; });
    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unsaved draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rail-4')));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(find.text('Unsaved draft'), findsWidgets);
    expect(find.text('Unsaved subtitle edit'), findsNothing);
    await choose(tester, 'studio-view-menu', 'Settings');
    expect(opens, 2);
    expect(find.text('Unsaved draft'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Help menu invokes the existing documentation host',
      (tester) async {
    var opens = 0;
    await launch(tester, help: () async { opens++; });
    await tester.tap(find.byKey(const ValueKey('studio-help-menu')));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('command palette aligns assigned shortcuts beside command names',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('desktop-command-palette')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('palette-shortcut-Find subtitle')),
        findsOneWidget);
    expect(find.text('Ctrl+F'), findsWidgets);
    expect(find.byKey(const ValueKey('palette-shortcut-Next line')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('palette-shortcut-Subtitle tools')),
        findsNothing, reason: 'Do not advertise a shortcut that is not bound');
  });

  testWidgets('Projects is the first sidebar item, replacing Switch project',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = -1;
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'One', edited: 'Edited',
      )],
      activeProjectId: 7,
      projects: const [
        StudioDockProjectEntry(id: 7, title: 'First.srt', isEditMode: false),
        StudioDockProjectEntry(id: 8, title: 'Second.srt', isEditMode: true),
      ],
      onSelectProject: (id) => selected = id,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-dock-switch-project')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('studio-dock-sidebar-projects')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-projects-list')), findsOneWidget);
    expect(find.text('First.srt'), findsOneWidget);
    await tester.tap(find.text('Second.srt'));
    await tester.pumpAndSettle();
    expect(selected, 8);
  });

  testWidgets('desktop menus dispatch actual editor sections',
      (tester) async {
    await launch(tester);
    await choose(tester, 'studio-edit-menu', 'Find & Replace');
    expect(find.byKey(const ValueKey('studio-find-section')), findsOneWidget);
    await choose(tester, 'studio-timing-menu', 'Edit start and end time');
    expect(find.byKey(const ValueKey('inspector-tab-Timing')), findsNothing);
    expect(find.text('START TIMECODE'), findsOneWidget);
    await choose(tester, 'studio-subtitle-menu', 'Review notes');
    expect(find.text('REVIEW NOTES'), findsOneWidget);
    await choose(tester, 'studio-tools-menu', 'Subtitle tools');
    expect(find.byKey(const ValueKey('studio-tools-section')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit menu reuses mobile text-copy selection semantics',
      (tester) async {
    String? copied;
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        SystemChannels.platform, null));
    await launch(tester);
    await choose(tester, 'studio-edit-menu', 'Select all visible subtitles');
    await choose(tester, 'studio-edit-menu', 'Copy selected subtitles');
    expect(copied, 'Edited line\n\nSecond original\n\n\n\nFinal edit');
    expect(tester.takeException(), isNull);
  });
}
