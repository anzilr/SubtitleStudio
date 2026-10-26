import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_loading_bars.dart';
import 'package:subtitle_studio/database/models/models.dart';

class _CompactReadyController extends WaveformController {
  @override
  WaveformState build() => WaveformReady(
    buffer: WaveformBuffer(
      rawData: WaveformData(
        channels: 1, sampleRate: 100, totalSamples: 1200,
        rawSamples: [Int16List(1200)],
      ),
      zoomLevels: [
        ZoomLevel(samplesPerPixel: 1,
          data: [List<WaveformSample>.filled(
            1200, const WaveformSample(0, 0))]),
        ZoomLevel(samplesPerPixel: 2,
          data: [List<WaveformSample>.filled(
            600, const WaveformSample(0, 0))]),
      ],
    ),
    currentZoomIndex: 0,
    viewportWidth: 490,
  );
}

class _CompactLoadingController extends WaveformController {
  @override
  WaveformState build() => const WaveformLoading(
    'source', progress: 0.3,
    processedAudioTime: Duration(seconds: 5),
  );
}

class _CompactErrorController extends WaveformController {
  @override
  WaveformState build() =>
      const WaveformError('Selected audio metadata is unavailable.');
}

void main() {
  testWidgets('desktop can place waveform actions in its only title row',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactReadyController.new),
      ],
      child: MaterialApp(home: Scaffold(body: SizedBox(
        width: 700, height: 180,
        child: WaveformWidget(
          height: 180, compact: true,
          subtitles: const [], enableTimeEditing: false,
          compactToolbarBuilder: (context, buttons) => Row(children: [
            const Text('WAVEFORM'),
            Expanded(child: buttons),
          ]),
        ),
      ))),
    ));
    await tester.pump();
    expect(find.text('WAVEFORM'), findsOneWidget);
    expect(find.byKey(const ValueKey('waveform-compact-zoom-in')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact waveform keeps zoom and playhead usable in 13% band',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactReadyController.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Center(
          child: SizedBox(width: 500, height: 87,
            child: WaveformWidget(
              compact: true, enableTimeEditing: false,
              height: 87, subtitles: [],
            ),
          ),
        )),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('waveform-compact-zoom-in')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('waveform-compact-zoom-out')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('waveform-compact-vertical-zoom-in')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('waveform-compact-vertical-zoom-out')),
        findsOneWidget);
    expect(tester.widget<WaveformWidget>(find.byType(WaveformWidget))
        .enableTimeEditing, isFalse);
    expect(find.byTooltip('Waveform Options'), findsNothing,
        reason: 'Full toolbar must not consume compact waveform height');
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact controls add cues and route edits through the host',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final line = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = 'Original';
    final edits = <String>[];
    final additions = <Duration>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactReadyController.new),
      ],
      child: MaterialApp(home: Scaffold(body: SizedBox(
        width: 500, height: 95,
        child: WaveformWidget(
          compact: true, enableTimeEditing: true,
          height: 95, subtitles: [line],
          onApplyTimeEdit: (number, start, end) async {
            edits.add('$number $start $end');
            return true;
          },
          onAddLineConfirmed: (start, end) {
            additions..add(start)..add(end);
          },
        ),
      ))),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('waveform-compact-add-line')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('waveform-compact-add-line')));
    await tester.pump();
    expect(find.byKey(const ValueKey('waveform-compact-apply')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('waveform-compact-apply')));
    await tester.pump();
    expect(additions, [Duration.zero, const Duration(seconds: 2)]);

    final controller = ProviderScope.containerOf(
        tester.element(find.byType(WaveformWidget)))
        .read(waveformControllerProvider.notifier);
    await controller.dispatch(const EnterTimeEditMode(0));
    await controller.dispatch(const UpdateTempEndTime(Duration(seconds: 3)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('waveform-compact-apply')));
    await tester.pump();
    expect(edits, ['1 00:00:01,000 00:00:03,000']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape cancels compact waveform time editing', (tester) async {
    final line = SubtitleLine()
      ..index = 1
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,000'
      ..original = 'Original';
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactReadyController.new),
      ],
      child: MaterialApp(home: Scaffold(body: SizedBox(
        width: 500, height: 96,
        child: WaveformWidget(compact: true, height: 96,
          subtitles: [line]),
      ))),
    ));
    final controller = ProviderScope.containerOf(
        tester.element(find.byType(WaveformWidget)))
        .read(waveformControllerProvider.notifier);
    controller.dispatch(const EnterTimeEditMode(0));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect((ProviderScope.containerOf(
        tester.element(find.byType(WaveformWidget)))
        .read(waveformControllerProvider) as WaveformReady).isEditMode, false);
    expect(tester.takeException(), isNull);
  });

  test('fine desktop zoom uses metadata without allocating peak arrays', () {
    final source = WaveformBuffer(
      rawData: WaveformData(
        channels: 1, sampleRate: 44100,
        totalSamples: 44100 * 600, rawSamples: [Int16List(1)]),
      zoomLevels: [ZoomLevel.metadata(
        samplesPerPixel: 700, pixelCount: 37800, channels: 1)],
    );
    final extended = WaveformController.extendDesktopFineZoom(source);
    expect(extended.zoomLevelCount, greaterThan(source.zoomLevelCount));
    expect(extended.zoomLevels.first.isMetadataOnly, isTrue);
    expect(extended.zoomLevels.first.materializedPixels, 0);
    expect(extended.zoomLevels.first.samplesPerPixel, lessThan(300));
    expect(extended.zoomLevels.last.samplesPerPixel, 700);
  });

  test('finest desktop zoom displays 1.5–2 seconds at different panel widths', () {
    final source = WaveformBuffer(
      rawData: WaveformData(
        channels: 1, sampleRate: 44100,
        totalSamples: 44100 * 600, rawSamples: [Int16List(1)]),
      zoomLevels: [ZoomLevel.metadata(
        samplesPerPixel: 700, pixelCount: 37800, channels: 1)],
    );

    for (final width in [640.0, 850.0, 1200.0, 1920.0, 2560.0]) {
      final extended = WaveformController.extendDesktopFineZoom(
        source, viewportWidth: width,
      );
      final visibleSeconds = width *
          extended.zoomLevels.first.samplesPerPixel / source.sampleRate;
      expect(visibleSeconds, inInclusiveRange(1.5, 2.0),
          reason: 'Fine zoom must fit $width px desktop waveform');
      expect(visibleSeconds,
          closeTo(WaveformController.desktopFineZoomSeconds, 0.05));
      expect(extended.zoomLevels.first.isMetadataOnly, isTrue);
      expect(extended.zoomLevels.first.materializedPixels, 0);
      expect(identical(extended.zoomLevels.last, source.zoomLevels.first), isTrue);
    }
  });

  test('desktop resize retains fine zoom and the timeline center', () {
    final source = WaveformBuffer(
      rawData: WaveformData(
        channels: 1, sampleRate: 48000,
        totalSamples: 48000 * 600, rawSamples: [Int16List(1)]),
      zoomLevels: [ZoomLevel.metadata(
        samplesPerPixel: 800, pixelCount: 36000, channels: 1)],
    );
    final beforeBuffer = WaveformController.extendDesktopFineZoom(
      source, viewportWidth: 850,
    );
    final fineCount = beforeBuffer.zoomLevelCount - source.zoomLevelCount;
    final before = WaveformReady(
      buffer: beforeBuffer,
      currentZoomIndex: 0,
      viewportWidth: 850,
      scrollPosition: 48000 * 100 / beforeBuffer.zoomLevels.first.samplesPerPixel,
    );
    final center = before.centerTimeForScroll(before.scrollPosition);
    final after = WaveformController.resizeDesktopFineZoom(
      before, viewportWidth: 1360, priorFineCount: fineCount,
    );

    expect(after.currentZoomIndex, 0);
    expect(after.viewportWidth, 1360);
    expect(1360 * after.samplesPerPixel / source.sampleRate,
        inInclusiveRange(1.5, 2.0));
    expect((after.centerTimeForScroll(after.scrollPosition) - center)
        .inMilliseconds.abs(), lessThanOrEqualTo(2));
    expect(identical(after.buffer.rawData, source.rawData), isTrue);
    expect(identical(after.buffer.zoomLevels.last, source.zoomLevels.first), isTrue);
    expect(after.buffer.zoomLevels.first.materializedPixels, 0);

    final nativeSelection = before.copyWith(currentZoomIndex: fineCount);
    final nativeResized = WaveformController.resizeDesktopFineZoom(
      nativeSelection, viewportWidth: 1360, priorFineCount: fineCount,
    );
    expect(nativeResized.currentZoomLevel, same(source.zoomLevels.first));
  });

  testWidgets('compact loading status fits a 65px waveform band',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactLoadingController.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(
          width: 480, height: 65,
          child: WaveformWidget(compact: true, height: 65, subtitles: []),
        )),
      ),
    ));
    await tester.pump();
    expect(find.text('Generating waveform…'), findsOneWidget);
    expect(find.byType(WaveformLoadingBars), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact waveform error is readable in short band',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        waveformControllerProvider.overrideWith(_CompactErrorController.new),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(
          width: 480, height: 65,
          child: WaveformWidget(compact: true, height: 65, subtitles: []),
        )),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('Waveform unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('auto track selection does not reuse saved FFmpeg track preference', () {
    const legacy = LoadAudioFile('video.mkv', subtitleCollectionId: 7);
    const selected = LoadAudioFile('video.mkv',
        subtitleCollectionId: 7, useSavedAudioTrackPreference: false);
    expect(legacy.useSavedAudioTrackPreference, true);
    expect(selected.useSavedAudioTrackPreference, false);
    expect(selected.audioTrackId, isNull);
    expect(legacy, isNot(selected));
  });
}
