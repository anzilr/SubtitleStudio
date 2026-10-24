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
          original: 'Second original', edited: 'Edited second',
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
        find.byKey(const ValueKey('desktop-edit-1')), 'Unsaved draft');
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
    await choose(tester, 'studio-help-menu', 'Help & Documentation');
    expect(opens, 1);
    expect(tester.takeException(), isNull);
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
    await launch(tester);
    await choose(tester, 'studio-edit-menu', 'Select all visible subtitles');
    await choose(tester, 'studio-edit-menu', 'Copy selected subtitles');
    expect((await Clipboard.getData('text/plain'))?.text,
        'Edited line\n\nEdited second');
    expect(tester.takeException(), isNull);
  });
}
