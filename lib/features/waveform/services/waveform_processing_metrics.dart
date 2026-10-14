/// Timing and allocation indicators for comparing the existing eager
/// waveform pipeline with the visible-range tile pipeline on real devices.
/// Counts are structural, not process RSS memory measurements.
class WaveformProcessingMetrics {
  final Duration sourceAcquisition;
  final Duration downsampling;
  final Duration zoomGeneration;
  final Duration total;
  final int decodedSamples;
  final int displaySamples;
  final int zoomPixels;

  const WaveformProcessingMetrics({
    required this.sourceAcquisition,
    required this.downsampling,
    required this.zoomGeneration,
    required this.total,
    required this.decodedSamples,
    required this.displaySamples,
    required this.zoomPixels,
  });

  @override
  String toString() =>
      'source=' + sourceAcquisition.inMilliseconds.toString() +
      'ms downsample=' + downsampling.inMilliseconds.toString() +
      'ms zoom=' + zoomGeneration.inMilliseconds.toString() +
      'ms total=' + total.inMilliseconds.toString() +
      'ms decoded=' + decodedSamples.toString() +
      ' display=' + displaySamples.toString() +
      ' zoomPixels=' + zoomPixels.toString();
}
