import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

WaveformReady _ready() => WaveformReady(
  buffer: WaveformBuffer(
    rawData: WaveformData(
      channels: 1,
      sampleRate: 100,
      totalSamples: 100,
      rawSamples: [Int16List(100)],
    ),
    zoomLevels: [
      ZoomLevel(
        samplesPerPixel: 1,
        data: [List<WaveformSample>.filled(
          100, const WaveformSample(0.0, 0.0),
        )],
      ),
    ],
  ),
  currentZoomIndex: 0,
  viewportWidth: 360,
);

class _ReadyWaveformController extends WaveformController {
  @override
  WaveformState build() => _ready();
}

SubtitleLine _cue(String text) => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:00,000'
  ..endTime = '00:00:01,000'
  ..original = text;

void main() {
  testWidgets('build-phase audio playback state cannot violate Riverpod',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        waveformControllerProvider.overrideWith(_ReadyWaveformController.new),
      ],
    );
    addTearDown(container.dispose);
    var triggered = false;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final waveform = ref.watch(waveformControllerProvider);
            if (!triggered) {
              triggered = true;
              // Simulates a native media position event during a frame.
              ref.read(waveformControllerProvider.notifier).dispatch(
                const UpdatePlaybackPosition(Duration(milliseconds: 500)),
              );
            }
            return Text(waveform.runtimeType.toString());
          }),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      (container.read(waveformControllerProvider) as WaveformReady)
          .playbackPosition,
      const Duration(milliseconds: 500),
    );
  });

  testWidgets('WaveformWidget parent subtitle and playback updates are safe',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        waveformControllerProvider.overrideWith(_ReadyWaveformController.new),
      ],
    );
    addTearDown(container.dispose);
    var position = Duration.zero;
    var cues = <SubtitleLine>[_cue('Before')];
    late StateSetter rebuild;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return Column(children: [
              TextButton(
                onPressed: () => rebuild(() {
                  position = const Duration(milliseconds: 500);
                  cues = [_cue('After')];
                }),
                child: const Text('Update waveform parent'),
              ),
              SizedBox(
                height: 260,
                width: 800,
                child: WaveformWidget(
                  subtitles: cues,
                  playbackPosition: position,
                ),
              ),
            ]);
          }),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Update waveform parent'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      (container.read(waveformControllerProvider) as WaveformReady)
          .playbackPosition,
      const Duration(milliseconds: 500),
    );
    expect(find.byType(WaveformWidget), findsOneWidget);
  });
}
