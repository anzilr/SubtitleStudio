import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';

class _VideoSlot extends StatefulWidget {
  const _VideoSlot({required this.onMount, required this.onDispose});
  final VoidCallback onMount;
  final VoidCallback onDispose;
  @override
  State<_VideoSlot> createState() => _VideoSlotState();
}

class _VideoSlotState extends State<_VideoSlot> {
  @override
  void initState() { super.initState(); widget.onMount(); }
  @override
  void dispose() { widget.onDispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Existing player instance'));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    StudioDockLayoutPreferences.prefix + 'videoOpen': true,
  }));

  Future<void> launch(WidgetTester tester, StudioDockPlaybackLink playback, {
    Widget? video,
    VoidCallback? toggle,
  }) async {
    tester.view.physicalSize = const Size(1680, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      playback: playback,
      videoSurface: video,
      onTogglePlayback: toggle,
      initialCues: const [
        StudioDockCue(id: 1, start: '00:00:01,000',
          end: '00:00:02,000', original: 'First', edited: ''),
      ],
    )));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('studio-media-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Floating transport is opt-in and reuses mounted player',
      (tester) async {
    final playback = StudioDockPlaybackLink();
    playback.attach((_) {});
    var mounts = 0;
    var disposes = 0;
    var toggles = 0;
    await launch(tester, playback,
      video: _VideoSlot(onMount: () => mounts++, onDispose: () => disposes++),
      toggle: () => toggles++,
    );
    expect(mounts, 1);
    expect(find.byKey(const ValueKey('studio-floating-playback')), findsNothing);
    await select(tester, 'Show floating playback button');
    final button = find.byKey(const ValueKey('studio-floating-playback'));
    expect(button, findsOneWidget);
    expect(tester.widget<IconButton>(button).tooltip, 'Play video');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(toggles, 1);
    playback.updatePlaying(true);
    await tester.pump();
    expect(tester.widget<IconButton>(button).tooltip, 'Pause video');
    await tester.tap(button);
    expect(toggles, 2);
    expect(mounts, 1);
    expect(disposes, 0);
    await select(tester, 'Hide floating playback button');
    expect(button, findsNothing);
    expect(mounts, 1);
    expect(disposes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(disposes, 1);
    playback.dispose();
  });

  testWidgets('Transport disables when shared playback link detaches',
      (tester) async {
    final playback = StudioDockPlaybackLink();
    playback.attach((_) {});
    var toggles = 0;
    await launch(tester, playback, video: const SizedBox(),
      toggle: () => toggles++);
    await select(tester, 'Show floating playback button');
    final finder = find.byKey(const ValueKey('studio-floating-playback'));
    expect(tester.widget<IconButton>(finder).onPressed, isNotNull);
    // Detaching an *already-paused* player must also disable the button.
    playback.detach();
    await tester.pump();
    expect(tester.widget<IconButton>(finder).onPressed, isNull);
    playback.attach((_) {});
    await tester.pump();
    expect(tester.widget<IconButton>(finder).onPressed, isNotNull);
    playback.updatePlaying(true);
    playback.detach();
    await tester.pump();
    expect(tester.widget<IconButton>(finder).onPressed, isNull);
    expect(tester.widget<IconButton>(finder).tooltip, 'Play video');
    expect(toggles, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    playback.dispose();
  });

  testWidgets('Floating control menu requires both video and playback action',
      (tester) async {
    final playback = StudioDockPlaybackLink();
    await launch(tester, playback, toggle: () {});
    await tester.tap(find.byKey(const ValueKey('studio-media-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Show floating playback button'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await launch(tester, playback, video: const SizedBox());
    await tester.tap(find.byKey(const ValueKey('studio-media-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Show floating playback button'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    playback.dispose();
  });
}
