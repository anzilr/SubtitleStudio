import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'dart:typed_data';

void main() {
  test('ready waveform tracks retain selected stream through zoom copies',
      () {
    final data = WaveformData(
      channels: 1, sampleRate: 2000, totalSamples: 10,
      rawSamples: [Int16List(10)],
    );
    final level = ZoomLevel.metadata(
      samplesPerPixel: 2, pixelCount: 5, channels: 1);
    final ready = WaveformReady(
      buffer: WaveformBuffer(rawData: data, zoomLevels: [level]),
      currentZoomIndex: 0,
      sourceFilePath: 'selected.mkv',
      audioTrackId: 'ffmpeg:stream:3',
    );
    expect(ready.audioTrackId, 'ffmpeg:stream:3');
    expect(ready.copyWith(scrollPosition: 10).audioTrackId,
        'ffmpeg:stream:3');
    expect(ready.copyWith(audioTrackId: 'auto').audioTrackId, 'auto');
    expect(ready.props, contains('ffmpeg:stream:3'));
  });
}
