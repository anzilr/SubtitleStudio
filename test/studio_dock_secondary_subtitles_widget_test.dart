import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

const _cue = StudioDockCue(
  id: 1, start: '00:00:01,000', end: '00:00:02,000',
  original: 'Original', edited: 'Translation',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> launch(
    WidgetTester tester, {
    Future<void> Function()? load,
    VoidCallback? toggle,
    bool visible = true,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [_cue],
      onLoadSecondarySubtitles: load,
      onToggleSecondarySubtitles: toggle,
      showSecondarySubtitles: visible,
    )));
    await tester.pumpAndSettle();
  }

  Future<void> tools(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('studio-media-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('secondary subtitle options are absent without live host',
      (tester) async {
    await launch(tester);
    await tools(tester);
    expect(find.text('Load secondary subtitles'), findsNothing);
    expect(find.text('Show secondary subtitles'), findsNothing);
    expect(find.text('Hide secondary subtitles'), findsNothing);
  });

  testWidgets('picker action waits for popup dismissal', (tester) async {
    var launches = 0;
    await launch(tester, load: () async { launches++; });
    await tools(tester);
    await tester.tap(find.text('Load secondary subtitles'));
    await tester.pumpAndSettle();
    expect(launches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top toolbar loads secondary subtitles directly', (tester) async {
    var launches = 0;
    await launch(tester, load: () async { launches++; });
    final button = find.byKey(
        const ValueKey('studio-dock-toolbar-secondary'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(launches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary toolbar action is absent without a load callback',
      (tester) async {
    await launch(tester);
    expect(find.byKey(const ValueKey('studio-dock-toolbar-secondary')),
        findsNothing);
  });

  testWidgets('visibility control keeps the saved track available',
      (tester) async {
    var toggles = 0;
    await launch(tester, toggle: () => toggles++);
    await tools(tester);
    expect(find.text('Hide secondary subtitles'), findsOneWidget);
    await tester.tap(find.text('Hide secondary subtitles'));
    await tester.pumpAndSettle();
    expect(toggles, 1);
    await launch(tester, toggle: () => toggles++, visible: false);
    await tools(tester);
    expect(find.text('Show secondary subtitles'), findsOneWidget);
    await tester.tap(find.text('Show secondary subtitles'));
    await tester.pumpAndSettle();
    expect(toggles, 2);
    expect(tester.takeException(), isNull);
  });
}
