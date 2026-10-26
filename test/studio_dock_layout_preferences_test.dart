import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import '../tool/studio_dock_demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new workspaces default to balanced video and waveform proportions',
      () async {
    final layout = await StudioDockLayoutPreferences().load();
    expect(layout.videoShare, .36);
    expect(layout.waveformShare, .24);
  });

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
    expect(layout.waveformShare, .12);
  });

  test('legacy default split migrates without losing visibility and widths',
      () async {
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'videoShare': .38,
      StudioDockLayoutPreferences.prefix + 'waveformShare': .24,
      StudioDockLayoutPreferences.prefix + 'videoOpen': true,
      StudioDockLayoutPreferences.prefix + 'waveformOpen': true,
      StudioDockLayoutPreferences.prefix + 'inspectorWidth': 380.0,
    });
    final repo = StudioDockLayoutPreferences();
    final migrated = await repo.load();
    expect(migrated.videoShare, .36);
    expect(migrated.waveformShare, .24);
    expect(migrated.videoOpen, true);
    expect(migrated.waveformOpen, true);
    expect(migrated.inspectorWidth, 380);
    await repo.save(migrated);
    expect((await repo.load()).videoShare, .36);
  });

  test('previous list-first default upgrades to balanced split', () async {
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'verticalPresetVersion': 2,
      StudioDockLayoutPreferences.prefix + 'videoShare': .26,
      StudioDockLayoutPreferences.prefix + 'waveformShare': .17,
      StudioDockLayoutPreferences.prefix + 'videoOpen': true,
      StudioDockLayoutPreferences.prefix + 'waveformOpen': true,
    });
    final layout = await StudioDockLayoutPreferences().load();
    expect(layout.videoShare, .36);
    expect(layout.waveformShare, .24);
    expect(layout.videoOpen, true);
    expect(layout.waveformOpen, true);
  });

  test('user-resized legacy splits are retained on upgrade', () async {
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'videoShare': .48,
      StudioDockLayoutPreferences.prefix + 'waveformShare': .20,
    });
    final restored = await StudioDockLayoutPreferences().load();
    expect(restored.videoShare, .48);
    expect(restored.waveformShare, .20);
  });

  testWidgets('laptop dock with both media panels leaves room for cue rows',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: List.generate(30, (i) => StudioDockCue(
        id: i + 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original $i', edited: 'Edited $i',
      )),
      videoSurface: const Center(child: Text('Video panel')),
      waveformSurface: const Center(child: Text('Waveform panel')),
    )));
    await tester.pumpAndSettle();
    for (final label in ['Show video panel', 'Show waveform panel']) {
      await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(find.text('Video panel'), findsOneWidget);
    expect(find.text('Waveform panel'), findsOneWidget);
    final tableHeight = tester.getSize(
        find.byKey(const ValueKey('dock-table-band'))).height;
    expect(tableHeight, greaterThan(260));
    // The compact header (34), column labels (26) and 28px cue rows leave
    // space for at least seven lines at a 768px-tall desktop window.
    expect((tableHeight - 34 - 26) / 28, greaterThanOrEqualTo(7));
    expect(find.byKey(const ValueKey('desktop-cue-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow toolbar keeps primary actions and offers overflow',
      (tester) async {
    tester.view.physicalSize = const Size(820, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var imports = 0;
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited',
      )],
      onImportFile: () => imports++,
      onInsertCue: (_, __) async => null,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-dock-insert-cue')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-command-palette')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import subtitles or project'));
    await tester.pumpAndSettle();
    expect(imports, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide toolbar orders project actions right of command palette',
      (tester) async {
    tester.view.physicalSize = const Size(1700, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited',
      )],
      onInsertCue: (_, __) async => null,
      onSplitCue: (_, __) async => null,
      onMergeCue: (_, __) async => null,
      onDeleteCue: (_) async => null,
      onChooseVideo: () {},
      onImportFile: () {},
      onNewProject: () {},
      onSaveFile: () async => StudioDockFileResult.saved,
      onRestoreHistory: (_, __, ___) async => null,
    )));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(
        const ValueKey('studio-main-menu-toolbar'))).height, 44);
    final topKeys = [
      'studio-dock-toolbar-new',
      'studio-dock-toolbar-import',
      'studio-dock-toolbar-video',
      'studio-dock-save-file',
      'studio-dock-undo',
      'studio-dock-redo',
      'toggle-explorer',
      'toggle-inspector',
    ];
    final topPositions = topKeys.map((key) =>
        tester.getTopLeft(find.byKey(ValueKey(key))).dx).toList();
    for (var i = 1; i < topPositions.length; i++) {
      expect(topPositions[i], greaterThan(topPositions[i - 1]));
    }
    final paletteX = tester.getTopLeft(find.byKey(
        const ValueKey('desktop-command-palette'))).dx;
    expect(paletteX, lessThan(topPositions.first));
    expect(paletteX, greaterThan(tester.getTopLeft(find.byKey(
        const ValueKey('studio-view-menu'))).dx));

    final cueHeaderKeys = [
      'desktop-cue-search',
      'studio-dock-insert-cue',
      'studio-dock-split-cue',
      'studio-dock-merge-cue',
      'studio-dock-delete-cue',
      'studio-go-to-line',
    ];
    final positions = cueHeaderKeys.map((key) =>
        tester.getTopLeft(find.byKey(ValueKey(key))).dx).toList();
    for (var i = 1; i < positions.length; i++) {
      expect(positions[i], greaterThan(positions[i - 1]));
    }
    expect(tester.getTopLeft(find.byKey(const ValueKey('studio-subtitle-count'))).dx,
        lessThan(positions.first));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact subtitle header keeps editing actions in one row',
      (tester) async {
    tester.view.physicalSize = const Size(640, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited',
      )],
      onInsertCue: (_, __) async => null,
      onSplitCue: (_, __) async => null,
      onMergeCue: (_, __) async => null,
      onDeleteCue: (_) async => null,
    )));
    await tester.pumpAndSettle();
    final initialError = tester.takeException();
    if (initialError != null) {
      for (final flex in tester.allRenderObjects.whereType<RenderFlex>()) {
        if (flex.direction != Axis.horizontal || !flex.hasSize) continue;
        final overflowingChildren = <String>[];
        flex.visitChildren((child) {
          if (child is! RenderBox || !child.hasSize ||
              child.parentData is! FlexParentData) return;
          final position = (child.parentData! as FlexParentData).offset;
          final farEdge = position.dx + child.size.width;
          if (farEdge > flex.size.width + .5) {
            overflowingChildren.add('${child.toStringShort()} right=$farEdge');
          }
        });
        if (overflowingChildren.isNotEmpty) {
          debugPrint('COMPACT HEADER DIAGNOSTIC: ${flex.debugCreator} '
              'size=${flex.size} children=$overflowingChildren');
        }
      }
    }
    expect(initialError, isNull,
        reason: 'Compact toolbar and subtitle header must initially fit');
    expect(find.byKey(const ValueKey('studio-cue-header-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-dock-insert-cue')), findsNothing);
    expect(find.byKey(const ValueKey('desktop-cue-search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-cue-header-more')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'Compact subtitle actions popup must fit');
    await tester.tap(find.text('Insert subtitle line'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('studio-confirm-insert')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    for (final label in ['Show video panel', 'Show waveform panel']) {
      await tester.tap(find.byKey(const ValueKey('studio-view-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
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
