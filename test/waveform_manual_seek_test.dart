import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_seek_coordinator.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

WaveformReady _ready({int totalSamples = 10000}) => WaveformReady(
      buffer: WaveformBuffer(
        rawData: WaveformData(
          channels: 1,
          sampleRate: 100,
          totalSamples: totalSamples,
          rawSamples: [Int16List(0)],
        ),
        zoomLevels: [
          ZoomLevel.metadata(
            samplesPerPixel: 1,
            pixelCount: totalSamples,
            channels: 1,
          ),
        ],
      ),
      currentZoomIndex: 0,
      viewportWidth: 100,
    );

class _ReadyController extends WaveformController {
  @override
  WaveformState build() => _ready();
}

void main() {
  testWidgets('forty fast drag updates send only one preview and final seek',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final seeks = <Duration>[];
    final completed = <Duration>[];
    var began = 0;
    final coordinator = WaveformSeekCoordinator(
      onBegin: () => began++,
      onPreview: seeks.add,
      onComplete: completed.add,
      onCancel: () => fail('Normal drag should finish'),
    );
    addTearDown(coordinator.dispose);

    coordinator.startDrag();
    for (var i = 0; i < 40; i++) {
      coordinator.updateDrag(Duration(milliseconds: 1000 + i * 17));
    }
    expect(began, 1);
    expect(seeks, [const Duration(milliseconds: 1000)]);
    coordinator.finishDrag();
    expect(completed, [const Duration(milliseconds: 1663)]);
    expect(seeks, [
      const Duration(milliseconds: 1000),
      const Duration(milliseconds: 1663),
    ]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(seeks, hasLength(2));
  });

  testWidgets('long drag is preview-throttled and release uses latest target',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final seeks = <Duration>[];
    final coordinator = WaveformSeekCoordinator(
      onBegin: () {},
      onPreview: seeks.add,
      onComplete: (_) {},
      onCancel: () {},
    );
    addTearDown(coordinator.dispose);
    coordinator.startDrag();
    coordinator.updateDrag(const Duration(seconds: 1));
    coordinator.updateDrag(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 180));
    coordinator.updateDrag(const Duration(seconds: 3));
    coordinator.finishDrag();
    expect(seeks, [
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      const Duration(seconds: 3),
    ]);
  });

  testWidgets('paused dragging does not flood decoder and seeks on release',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final seeks = <Duration>[];
    final completed = <Duration>[];
    var playing = false;
    final coordinator = WaveformSeekCoordinator(
      shouldPreview: () => playing,
      onBegin: () {},
      onPreview: seeks.add,
      onComplete: completed.add,
      onCancel: () {},
    );
    addTearDown(coordinator.dispose);

    coordinator.startDrag();
    for (var i = 0; i < 40; i++) {
      coordinator.updateDrag(Duration(milliseconds: i * 100));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(seeks, isEmpty);
    coordinator.finishDrag();
    expect(completed, [const Duration(milliseconds: 3900)]);
    expect(seeks, [const Duration(milliseconds: 3900)]);

    // Resume playback: a subsequent drag may issue bounded previews.
    playing = true;
    coordinator.startDrag();
    coordinator.updateDrag(const Duration(seconds: 5));
    coordinator.finishDrag();
    expect(seeks, [
      const Duration(milliseconds: 3900),
      const Duration(seconds: 5),
      const Duration(seconds: 5),
    ]);
  });

  testWidgets('wheel bursts settle once at last position and dispose cancels',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final seeks = <Duration>[];
    final completed = <Duration>[];
    final coordinator = WaveformSeekCoordinator(
      onBegin: () {},
      onPreview: seeks.add,
      onComplete: completed.add,
      onCancel: () {},
    );
    coordinator.scrollWheel(const Duration(seconds: 1));
    coordinator.scrollWheel(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 150));
    coordinator.scrollWheel(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 220));
    expect(completed, [const Duration(seconds: 3)]);
    expect(seeks, [const Duration(seconds: 1), const Duration(seconds: 3)]);
    coordinator.scrollWheel(const Duration(seconds: 4));
    coordinator.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(completed, hasLength(1));
  });

  test('manual scroll can place either endpoint under the editing cursor', () {
    final ready = _ready();
    expect(ready.minScrollPosition, -50);
    expect(ready.maxScrollPosition, 9950);
    expect(ready.clampScrollPosition(-1000), -50);
    expect(ready.centerTimeForScroll(-1000),
        Duration.zero);
    expect(ready.clampScrollPosition(999999), 9950);
    expect(ready.centerTimeForScroll(999999),
        const Duration(seconds: 100));
    expect(ready.centerTimeForScroll(0),
        const Duration(milliseconds: 500),
        reason: 'Existing paused seek precision in the middle is preserved');

    final short = _ready(totalSamples: 30);
    expect(short.maxScrollPosition, -20);
    expect(short.centerTimeForScroll(-999), Duration.zero);
    expect(short.centerTimeForScroll(999999),
        const Duration(milliseconds: 300));
  });

  test('cursor coordinate follows time at the start, center, and end', () {
    final ready = _ready();
    expect(ready.playheadViewportX, 0);
    expect(ready.copyWith(playbackPosition: const Duration(milliseconds: 230))
        .playheadViewportX, 23);
    expect(ready.copyWith(
      playbackPosition: const Duration(milliseconds: 5500),
      scrollPosition: 500,
    ).playheadViewportX, 50);
    expect(ready.copyWith(
      playbackPosition: const Duration(seconds: 100),
      scrollPosition: ready.maxScrollPosition,
    ).playheadViewportX, 50);
  });

  test('manual seek reaches exact zero and final audio sample', () async {
    final container = ProviderContainer(overrides: [
      waveformControllerProvider.overrideWith(_ReadyController.new),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(waveformControllerProvider.notifier);

    controller.beginManualScrub();
    await controller.dispatch(const ScrollSeekToTime(-999));
    var state = container.read(waveformControllerProvider) as WaveformReady;
    expect(state.playbackPosition, Duration.zero);
    expect(state.playheadViewportX, 50);
    controller.completeManualScrub(Duration.zero);

    controller.beginManualScrub();
    await controller.dispatch(const ScrollSeekToTime(999999));
    state = container.read(waveformControllerProvider) as WaveformReady;
    expect(state.playbackPosition, const Duration(seconds: 100));
    expect(state.playheadViewportX, 50);
    controller.completeManualScrub(state.playbackPosition);
  });

  test('stale playback cannot recenter during drag or before final seek ack',
      () async {
    final container = ProviderContainer(overrides: [
      waveformControllerProvider.overrideWith(_ReadyController.new),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(waveformControllerProvider.notifier);

    controller.beginManualScrub();
    await controller.dispatch(const ScrollSeekToTime(500));
    var ready = container.read(waveformControllerProvider) as WaveformReady;
    expect(ready.scrollPosition, 500);
    expect(ready.playbackPosition, const Duration(milliseconds: 5500));

    await controller.dispatch(
      const UpdatePlaybackPosition(Duration(milliseconds: 1200)),
    );
    ready = container.read(waveformControllerProvider) as WaveformReady;
    expect(ready.scrollPosition, 500);
    expect(ready.playbackPosition, const Duration(milliseconds: 5500));

    controller.completeManualScrub(const Duration(milliseconds: 5500));
    await controller.dispatch(
      const UpdatePlaybackPosition(Duration(milliseconds: 3500)),
    );
    ready = container.read(waveformControllerProvider) as WaveformReady;
    expect(ready.scrollPosition, 500);

    await controller.dispatch(
      const UpdatePlaybackPosition(Duration(milliseconds: 5480)),
    );
    ready = container.read(waveformControllerProvider) as WaveformReady;
    expect(ready.scrollPosition, closeTo(498, 0.001));
    expect(ready.playbackPosition,
        const Duration(milliseconds: 5480));
  });
}
