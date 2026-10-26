import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_workspace.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_layout_preferences.dart';

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

  test('explicit audio tracks never masquerade as an old cached stream', () {
    final link = StudioDockPlaybackLink();
    expect(link.audio.value.status, StudioDockAudioStatus.waiting);
    link.updateAudioReady('auto', null);
    expect(link.audio.value.status, StudioDockAudioStatus.ready);
    expect(link.audio.value.streamSelector, isNull);

    link.prepareAudio();
    expect(link.audio.value.status, StudioDockAudioStatus.waiting);
    link.updateAudioReady('3', 'ffmpeg:stream:5');
    expect(link.audio.value.trackId, '3');
    expect(link.audio.value.streamSelector, 'ffmpeg:stream:5');

    link.updateAudioUnavailable('4', 'Verified stream metadata missing');
    expect(link.audio.value.status, StudioDockAudioStatus.unavailable);
    expect(link.audio.value.streamSelector, isNull);
    expect(link.audio.value.error, contains('metadata missing'));
    link.detach();
    expect(link.audio.value.status, StudioDockAudioStatus.waiting);
    link.dispose();
  });

  testWidgets('unmounting video does not notify waveform during tree lock',
      (tester) async {
    final link = StudioDockPlaybackLink();
    Widget frame({required bool showVideo}) => MaterialApp(
      home: Column(children: [
        if (showVideo) _RetiringPlaybackSurface(link: link),
        ValueListenableBuilder<StudioDockAudioSource>(
          valueListenable: link.audio,
          builder: (_, audio, __) => Text(audio.status.name),
        ),
      ]),
    );

    await tester.pumpWidget(frame(showVideo: true));
    link.updateAudioReady('auto', null);
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
    expect(link.isAttached, true);

    // The builder stays mounted when the video State is unmounted. A direct
    // detach() in dispose() would throw markNeedsBuild during finalizeTree.
    await tester.pumpWidget(frame(showVideo: false));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(link.isAttached, false);
    expect(link.audio.value.status, StudioDockAudioStatus.waiting);
    expect(find.text('waiting'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    link.dispose();
  });

  testWidgets('deferred detach cannot disconnect a replacement video',
      (tester) async {
    final link = StudioDockPlaybackLink();
    final replacementSeeks = <Duration>[];
    link.attach((_) {});
    link.updateAudioReady('auto', null);
    link.detachAfterFrame();
    link.attach(replacementSeeks.add);

    await tester.pump();
    expect(link.isAttached, true);
    expect(link.audio.value.status, StudioDockAudioStatus.ready);
    link.seek(const Duration(seconds: 7));
    expect(replacementSeeks, [const Duration(seconds: 7)]);
    link.detach();
    link.dispose();
  });

  testWidgets('desktop menus and compact subtitle rows use intended sizes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1720, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: [
          StudioDockCue(
            id: 1,
            start: '00:00:01,000',
            end: '00:00:02,000',
            original: 'Readable subtitle row',
            edited: 'Readable edited row',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    final fileMenu = tester.widget<Text>(find.text('File'));
    expect(fileMenu.style!.fontSize, greaterThanOrEqualTo(14));
    final row = find.byKey(const ValueKey('desktop-cue-1'));
    final lineText = tester.widget<Text>(find.descendant(
      of: row,
      matching: find.text('Readable subtitle row'),
    ));
    expect(lineText.style!.fontSize, 13);
    final inspectorTab = tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('inspector-tab-Text')),
      matching: find.text('Text'),
    ));
    expect(inspectorTab.style!.fontSize, greaterThanOrEqualTo(14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('subtitle header uses line navigation and follow-sync icons',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final link = StudioDockPlaybackLink();
    await tester.pumpWidget(MaterialApp(home: StudioDockWorkspace(
      isLiveSession: true,
      initialCues: const [StudioDockCue(
        id: 1, start: '00:00:01,000', end: '00:00:02,000',
        original: 'Original', edited: 'Edited',
      )],
      playback: link,
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('studio-go-to-line')),
      matching: find.byType(Icon),
    )).icon, Icons.format_list_numbered_rounded);
    expect(tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('studio-dock-follow-playback')),
      matching: find.byType(Icon),
    )).icon, Icons.sync_rounded);
    await tester.tap(find.byKey(const ValueKey('studio-dock-follow-playback')));
    await tester.pump();
    expect(tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('studio-dock-follow-playback')),
      matching: find.byType(Icon),
    )).icon, Icons.sync_disabled_rounded);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    link.dispose();
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
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: const [
          StudioDockCue(id: 1, start: '00:00:01,000',
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
    SharedPreferences.setMockInitialValues({
      StudioDockLayoutPreferences.prefix + 'videoOpen': true,
      StudioDockLayoutPreferences.prefix + 'waveformOpen': true,
    });
    tester.view.physicalSize = const Size(1750, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var videoMounts = 0;
    var waveformMounts = 0;
    var videoDisposals = 0;
    var waveformDisposals = 0;

    await tester.pumpWidget(MaterialApp(
      home: StudioDockWorkspace(
        isLiveSession: true,
        initialCues: const [
          StudioDockCue(
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
    expect(find.text('real waveform'), findsOneWidget,
        reason: 'The provided waveform owns its header and playback state');

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

class _RetiringPlaybackSurface extends StatefulWidget {
  const _RetiringPlaybackSurface({required this.link});

  final StudioDockPlaybackLink link;

  @override
  State<_RetiringPlaybackSurface> createState() =>
      _RetiringPlaybackSurfaceState();
}

class _RetiringPlaybackSurfaceState extends State<_RetiringPlaybackSurface> {
  @override
  void initState() {
    super.initState();
    widget.link.attach((_) {});
  }

  @override
  void dispose() {
    widget.link.detachAfterFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
