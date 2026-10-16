import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

class _ReadyController extends WaveformController {
  @override
  WaveformState build() => WaveformReady(
    buffer: WaveformBuffer(
      rawData: WaveformData(
        channels: 1, sampleRate: 100, totalSamples: 400,
        rawSamples: [Int16List(400)],
      ),
      zoomLevels: [
        ZoomLevel(
          samplesPerPixel: 1,
          data: [List<WaveformSample>.filled(400, const WaveformSample(0, 0))],
        ),
        ZoomLevel(
          samplesPerPixel: 2,
          data: [List<WaveformSample>.filled(200, const WaveformSample(0, 0))],
        ),
      ],
    ),
    currentZoomIndex: 0,
    viewportWidth: 300,
  );
}

void main() {
  testWidgets('waveform toolbar remains usable at 360dp without RenderFlex overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_ReadyController.new),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 270,
              child: WaveformWidget(subtitles: []),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byTooltip('Zoom In'), findsOneWidget);
    expect(find.byTooltip('Waveform Options'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final toolbarScroller = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(toolbarScroller, findsWidgets);
    await tester.drag(toolbarScroller.first, const Offset(-110, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
