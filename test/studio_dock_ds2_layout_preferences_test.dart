import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import '../tool/studio_dock_demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('local dock preferences round-trip widths, splits and visibility',
      () async {
    final repo = StudioDockLayoutPreferences();
    const expected = StudioDockLayoutSnapshot(
      explorerWidth: 310,
      inspectorWidth: 410,
      videoShare: .52,
      waveformShare: .24,
      explorerOpen: false,
      inspectorOpen: false,
      videoOpen: true,
      waveformOpen: true,
    );
    await repo.save(expected);
    final loaded = await repo.load();

    expect(loaded.explorerWidth, 310);
    expect(loaded.inspectorWidth, 410);
    expect(loaded.videoShare, .52);
    expect(loaded.waveformShare, .24);
    expect(loaded.explorerOpen, false);
    expect(loaded.inspectorOpen, false);
    expect(loaded.videoOpen, true);
    expect(loaded.waveformOpen, true);
  });

  test('invalid layout values are clamped to safe window limits', () async {
    final repo = StudioDockLayoutPreferences();
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'explorerWidth': 1000.0,
      StudioDockLayoutPreferences.prefix + 'inspectorWidth': 45.0,
      StudioDockLayoutPreferences.prefix + 'videoShare': 999.0,
      StudioDockLayoutPreferences.prefix + 'waveformShare': -12.0,
    });
    final layout = await repo.load();

    expect(layout.explorerWidth, 340);
    expect(layout.inspectorWidth, 280);
    expect(layout.videoShare, .62);
    expect(layout.waveformShare, .18);
  });

  testWidgets('wide preview restores hidden explorer and reset restores it',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'explorerOpen': false,
      StudioDockLayoutPreferences.prefix + 'inspectorOpen': true,
    });
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const StudioDockDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('PROJECT'), findsNothing);
    expect(find.text('LINE INSPECTOR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-command-palette')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('palette-search')), 'reset workspace');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset workspace layout'));
    await tester.pumpAndSettle();

    expect(find.text('PROJECT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('media panels are opt-in and persisted for valid surfaces',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget build() => MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [StudioDockCue(
          id: 1, start: '00:00:01,000', end: '00:00:02,000',
          original: 'Original', edited: 'Edited')],
      videoSurface: const Center(child: Text('Valid video surface')),
      waveformSurface: const Center(child: Text('Valid waveform surface')),
    ));
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dock-video-band')), findsNothing);
    expect(find.byKey(const ValueKey('dock-waveform-band')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('studio-toggle-video-panel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-toggle-waveform-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Valid video surface'), findsOneWidget);
    expect(find.text('Valid waveform surface'), findsOneWidget);
    final stored = await StudioDockLayoutPreferences().load();
    expect(stored.videoOpen, true);
    expect(stored.waveformOpen, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching edit mode into translation mode restores original column',
      (tester) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget project(int id, bool edit) => MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        activeProjectId: id,
        isEditMode: edit,
        initialCues: [StudioDockCue(
          id: 1, start: '00:00:01,000', end: '00:00:02,000',
          original: edit ? 'Creation' : 'Original translation source',
          edited: edit ? 'Created line' : 'Translated line',
        )],
      ),
    );
    await tester.pumpWidget(project(1, true));
    await tester.pumpAndSettle();
    expect(find.text('EDITED'), findsNothing);
    await tester.pumpWidget(project(2, false));
    await tester.pumpAndSettle();
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('EDITED'), findsOneWidget);
    expect(find.text('Original translation source'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
