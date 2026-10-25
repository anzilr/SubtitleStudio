import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_media_plan.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_snapshot.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';

void main() {
  test('saved video needs an existing path before the native player can mount',
      () async {
    var checks = 0;
    expect(await StudioDockMediaPlan.resolveVideoPath(
      collectionId: 3,
      getSavedPath: (_) async => null,
      exists: (_) async { checks++; return true; },
    ), isNull);
    expect(checks, 0);
    expect(await StudioDockMediaPlan.resolveVideoPath(
      collectionId: 3,
      getSavedPath: (_) async => 'not-there.mp4',
      exists: (_) async => false,
    ), isNull);
    expect(await StudioDockMediaPlan.resolveVideoPath(
      collectionId: 3,
      getSavedPath: (_) async => 'present.mp4',
      exists: (_) async => true,
    ), 'present.mp4');
  });

  test('subtitle player mapping distinguishes null edit, blank edit and bad cue',
      () {
    final session = StudioDockSessionSnapshot(
      sessionId: 1,
      collectionId: 5,
      fileName: 'example.srt',
      encoding: 'UTF-8',
      cues: const [
        StudioDockLoadedCue(index: 1, start: '00:00:01,200',
          end: '00:00:02,300', original: 'Original',
          edited: '', storedEdited: null, marked: true, comment: 'Note'),
        StudioDockLoadedCue(index: 2, start: '00:00:02,400',
          end: '00:00:03,500', original: 'Intentionally hidden',
          edited: '', storedEdited: '', marked: false),
        StudioDockLoadedCue(index: 3, start: 'not a time',
          end: '00:00:04,000', original: 'Invalid cue',
          edited: '', marked: false),
        StudioDockLoadedCue(index: 4, start: '00:00:05,000',
          end: '00:00:04,900', original: 'Negative length',
          edited: '', marked: false),
      ],
    );
    final mapped = StudioDockMediaPlan.overlayCues(session);
    expect(mapped, hasLength(2));
    expect(mapped[0].index, 1);
    expect(mapped[0].start, const Duration(milliseconds: 1200));
    expect(mapped[0].end, const Duration(milliseconds: 2300));
    expect(mapped[0].text, 'Original');
    expect(mapped[0].marked, isTrue);
    expect(mapped[0].comment, 'Note');
    expect(mapped[1].text, isEmpty);
  });

  testWidgets('standalone Studio Dock toolbar exposes New and Import',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var imports = 0;
    var newProjects = 0;
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'Source', edited: ''),
        ],
        onImportFile: () => imports++,
        onNewProject: () => newProjects++,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-import')));
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-new')));
    await tester.pump();
    expect(imports, 1);
    expect(newProjects, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native player slot survives changing Studio Dock sections',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'videoOpen': true,
    });
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var mounted = 0;
    var disposed = 0;
    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        initialCues: const [
          StudioDockCue(
            id: 1, start: '00:00:01,000', end: '00:00:02,000',
            original: 'Actual cue', edited: 'Edited cue'),
        ],
        isLiveSession: true,
        videoSurface: _TestVideoSlot(
          onMount: () => mounted++,
          onDispose: () => disposed++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(mounted, 1);
    expect(disposed, 0);

    await tester.tap(find.byKey(const ValueKey('rail-1')));
    await tester.pumpAndSettle();
    expect(mounted, 1);
    expect(disposed, 0);

    await tester.tap(find.byKey(const ValueKey('rail-0')));
    await tester.pumpAndSettle();
    expect(mounted, 1);
    expect(disposed, 0);
    expect(tester.takeException(), isNull);
  });
}

class _TestVideoSlot extends StatefulWidget {
  const _TestVideoSlot({required this.onMount, required this.onDispose});
  final VoidCallback onMount;
  final VoidCallback onDispose;
  @override
  State<_TestVideoSlot> createState() => _TestVideoSlotState();
}

class _TestVideoSlotState extends State<_TestVideoSlot> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Injected player surface'));
}
