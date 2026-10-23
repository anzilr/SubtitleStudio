import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/responsive_layout.dart';
import 'package:subtitle_studio/widgets/adaptive_waveform_pane.dart';

void main() {
  testWidgets('legacy .25 mobile ratio cannot squeeze the fixed-height waveform',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 700,
          child: ResizableSplitView(
            vertical: true,
            initialRatio: 0.25486577181208037,
            minRatio: 0.2,
            maxRatio: 0.8,
            dividerThickness: 6,
            minFirstPaneExtent: AdaptiveWaveformPane.minimumPreferredPaneHeight,
            leftChild: const AdaptiveWaveformPane(
              video: ColoredBox(key: Key('video'), color: Colors.black),
              waveform: ColoredBox(key: Key('waveform'), color: Colors.grey),
              showWaveform: true,
            ),
            rightChild: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(find.byKey(const Key('waveform')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('video'))).height,
        greaterThanOrEqualTo(AdaptiveWaveformPane.minimumVideoHeight));
    expect(tester.getSize(find.byKey(const Key('waveform'))).height,
        lessThanOrEqualTo(AdaptiveWaveformPane.preferredWaveformHeight));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short viewport never makes video zero-height or overflows',
      (tester) async {
    tester.view.physicalSize = const Size(360, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 177.2,
          child: AdaptiveWaveformPane(
            showWaveform: true,
            video: ColoredBox(key: Key('video'), color: Colors.black),
            waveform: ColoredBox(key: Key('waveform'), color: Colors.grey),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(find.byKey(const Key('waveform')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('video'))).height, 177.2);
    expect(tester.takeException(), isNull);
  });
}
