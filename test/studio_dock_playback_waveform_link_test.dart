import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/desktop_workspace_preview.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';

void main() {
  test('waveform seeks through the attached native player only', () {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    expect(link.isAttached, false);
    link.seek(const Duration(seconds: 3));
    expect(seeks, isEmpty);

    link.attach(seeks.add);
    link.updatePosition(const Duration(milliseconds: 1750));
    link.updatePlaying(true);
    expect(link.position.value, const Duration(milliseconds: 1750));
    expect(link.playing.value, true);
    link.seek(const Duration(seconds: 8));
    link.seek(const Duration(milliseconds: -50));
    expect(seeks, [const Duration(seconds: 8), Duration.zero]);

    link.detach();
    expect(link.isAttached, false);
    expect(link.playing.value, false);
    link.seek(const Duration(seconds: 9));
    expect(seeks.length, 2);
    link.dispose();
    link.seek(const Duration(seconds: 10));
    expect(seeks.length, 2);
  });

  testWidgets('attach-video command is available without classic editor',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1720, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
      home: DesktopWorkspacePreview(
        liveReadOnly: true,
        initialCues: const [
          WorkspaceDemoCue(id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'Source', edited: 'Old edit'),
        ],
        onApplyCueText: (_, __) async => true,
        onChooseVideo: () => opens++,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-video')));
    await tester.pump();
    expect(opens, 1);

    await tester.enterText(
        find.byKey(const ValueKey('studio-edit-1-0')), 'Unsaved media draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-dock-toolbar-video')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved subtitle edit'), findsOneWidget);
    expect(opens, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separate video and waveform surfaces retain their owner State',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1750, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var videoMounts = 0;
    var waveformMounts = 0;
    var videoDisposals = 0;
    var waveformDisposals = 0;

    await tester.pumpWidget(MaterialApp(
      home: DesktopWorkspacePreview(
        liveReadOnly: true,
        initialCues: const [
          WorkspaceDemoCue(
            id: 1, start: '00:00:01,000',
            end: '00:00:02,000', original: 'Original', edited: ''),
        ],
        videoSurface: _TrackedSurface(
          label: 'native video', onMount: () => videoMounts++,
          onDispose: () => videoDisposals++,
        ),
        waveformSurface: _TrackedSurface(
          label: 'real waveform', onMount: () => waveformMounts++,
          onDispose: () => waveformDisposals++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(videoMounts, 1);
    expect(waveformMounts, 1);
    expect(find.text('Synced with video'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-0')));
    await tester.pumpAndSettle();
    expect(videoMounts, 1, reason: 'No native player recreation on tab switch');
    expect(waveformMounts, 1, reason: 'No waveform decoding restart on switch');
    expect(videoDisposals, 0);
    expect(waveformDisposals, 0);
    expect(tester.takeException(), isNull);
  });
}

class _TrackedSurface extends StatefulWidget {
  const _TrackedSurface({
    required this.label,
    required this.onMount,
    required this.onDispose,
  });
  final String label;
  final VoidCallback onMount;
  final VoidCallback onDispose;

  @override
  State<_TrackedSurface> createState() => _TrackedSurfaceState();
}

class _TrackedSurfaceState extends State<_TrackedSurface> {
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
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}
