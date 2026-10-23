import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_acquisition_timings.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_processing_metrics.dart';

void main() {
  test('cold compact waveform trace distinguishes FFmpeg and peak reduction', () {
    const stages = WaveformAcquisitionTimings(
      mode: WaveformAcquisitionMode.ffmpegCompactBuild,
      ffmpeg: Duration(milliseconds: 145000),
      peakReduction: Duration(milliseconds: 832),
      pcmBytes: 40100000,
    );
    final trace = stages.toString();
    expect(trace, contains('acquisition=ffmpegCompactBuild'));
    expect(trace, contains('ffmpegMs=145000'));
    expect(trace, contains('peakMs=832'));
    expect(trace, contains('acquisitionBytes=40100000'));
    expect(trace, isNot(contains('cacheMs=')));
  });

  test('cache hit records cache load without suggesting FFmpeg ran', () {
    const details = WaveformAcquisitionTimings(
      mode: WaveformAcquisitionMode.compactPeakCache,
      cacheLoad: Duration(milliseconds: 1810),
      pcmBytes: 40100028,
    );
    const summary = WaveformProcessingMetrics(
      sourceAcquisition: Duration(milliseconds: 1900),
      downsampling: Duration.zero,
      zoomGeneration: Duration(milliseconds: 30),
      total: Duration(milliseconds: 1930),
      decodedSamples: 20000000,
      displaySamples: 20000000,
      zoomPixels: 0,
      acquisitionDetails: details,
    );
    expect(summary.toString(), contains('acquisition=compactPeakCache'));
    expect(summary.toString(), contains('cacheMs=1810'));
    expect(summary.toString(), isNot(contains('ffmpegMs=')));
    expect(summary.toString(), isNot(contains('peakMs=')));
  });

  test('legacy structural metric format remains compatible', () {
    const summary = WaveformProcessingMetrics(
      sourceAcquisition: Duration(milliseconds: 10),
      downsampling: Duration(milliseconds: 2),
      zoomGeneration: Duration(milliseconds: 3),
      total: Duration(milliseconds: 15),
      decodedSamples: 100,
      displaySamples: 100,
      zoomPixels: 0,
    );
    expect(summary.toString(), contains('source=10ms downsample=2ms'));
    expect(summary.toString(), isNot(contains('acquisition=')));
  });
}
