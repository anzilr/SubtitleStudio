import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_loading_bars.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

class _ClockController extends WaveformController {
  @override
  WaveformState build() => WaveformReady(
        buffer: WaveformBuffer(
          rawData: WaveformData(
            channels: 1,
            sampleRate: 100,
            totalSamples: 10000,
            rawSamples: [Int16List(10000)],
          ),
          zoomLevels: [
            ZoomLevel(
              samplesPerPixel: 1,
              data: [List<WaveformSample>.filled(
                10000, const WaveformSample(0, 0),
              )],
            ),
          ],
        ),
        currentZoomIndex: 0,
        viewportWidth: 400,
        playbackPosition: const Duration(milliseconds: 1200),
      );
}

class _LoadingController extends WaveformController {
  @override
  WaveformState build() => const WaveformLoading('source',
        progress: 0.1,
        processedAudioTime: Duration(seconds: 25),
        totalAudioTime: Duration(seconds: 100),
      );
}

void main() {
  testWidgets('bottom left clock follows actual cursor before center and at end',
      (tester) async {
    final container = ProviderContainer(overrides: [
      waveformControllerProvider.overrideWith(_ClockController.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 230,
            child: WaveformWidget(subtitles: []),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('00:00:01,200'), findsOneWidget);
    expect(find.text('00:00:02,000'), findsNothing,
        reason: 'The viewport midpoint must not drive the clock');

    await container.read(waveformControllerProvider.notifier).dispatch(
          const UpdatePlaybackPosition(Duration(milliseconds: 99750)),
        );
    await tester.pump();
    expect(find.text('00:01:39,750'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio loader renders real fractional waveform fill',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_LoadingController.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 430,
            height: 180,
            child: WaveformWidget(subtitles: []),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));

    final bars = tester.widget<WaveformLoadingBars>(
      find.byType(WaveformLoadingBars),
    );
    expect(bars.fillFraction, closeTo(0.2125, 0.0001));
    expect(find.text('Audio processed: 0:00:25 / 0:01:40'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
