import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_preferences_repository.dart';
import 'package:subtitle_studio/features/waveform/services/audio_processor.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

class UnusedPreferences implements WaveformPreferencesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PendingAudioProcessor extends AudioProcessor {
  PendingAudioProcessor() : super(UnusedPreferences());
  final Map<String, Completer<WaveformBuffer>> requests = {};
  final Map<String, Function(double)?> progressCallbacks = {};
  final Map<String, void Function(Duration)?> decodeTimeCallbacks = {};

  @override
  Future<WaveformBuffer> processAudioFile(
    String audioFilePath, {
    Function(double)? onProgress,
    void Function(Duration)? onDecodedAudioTime,
    int? subtitleCollectionId,
    String? audioTrackId,
  }) {
    progressCallbacks[audioFilePath] = onProgress;
    decodeTimeCallbacks[audioFilePath] = onDecodedAudioTime;
    return (requests[audioFilePath] ??= Completer<WaveformBuffer>()).future;
  }

  void complete(String path) {
    requests[path]!.complete(WaveformBuffer(
      rawData: WaveformData(channels: 1, sampleRate: 8,
        totalSamples: 2, rawSamples: [Int16List.fromList([0, 100])]),
      zoomLevels: [ZoomLevel(samplesPerPixel: 1,
        data: [[const WaveformSample(0, 0),
                const WaveformSample(0.1, 0.1)]])],
    ));
  }
}

void main() {
  test('older audio load and progress cannot replace newer ready waveform',
      () async {
    final processor = PendingAudioProcessor();
    final container = ProviderContainer(overrides: [
      waveformAudioProcessorProvider.overrideWithValue(processor),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(waveformControllerProvider.notifier);
    final old = controller.dispatch(const LoadAudioFile('audio-old'));
    final latest = controller.dispatch(const LoadAudioFile('audio-latest'));
    processor.complete('audio-latest');
    await latest;
    expect((container.read(waveformControllerProvider) as WaveformReady)
        .sourceFilePath, 'audio-latest');

    processor.progressCallbacks['audio-old']?.call(0.75);
    processor.decodeTimeCallbacks['audio-old']?.call(
        const Duration(minutes: 10));
    processor.complete('audio-old');
    await old;
    final result = container.read(waveformControllerProvider);
    expect(result, isA<WaveformReady>());
    expect((result as WaveformReady).sourceFilePath, 'audio-latest');
  });

  test('clear invalidates an in-flight audio processing request', () async {
    final processor = PendingAudioProcessor();
    final container = ProviderContainer(overrides: [
      waveformAudioProcessorProvider.overrideWithValue(processor),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(waveformControllerProvider.notifier);
    final pending = controller.dispatch(const LoadAudioFile('audio-pending'));
    await controller.dispatch(const ClearWaveform());
    expect(container.read(waveformControllerProvider), isA<WaveformInitial>());
    processor.progressCallbacks['audio-pending']?.call(0.5);
    processor.decodeTimeCallbacks['audio-pending']?.call(
        const Duration(hours: 1));
    processor.complete('audio-pending');
    await pending;
    expect(container.read(waveformControllerProvider), isA<WaveformInitial>());
  });
}
