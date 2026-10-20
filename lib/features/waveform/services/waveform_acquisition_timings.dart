/// Small native/desktop diagnostic breakdown of one waveform source load.
///
/// This deliberately never stores source paths or SAF document identifiers.
/// It measures time in FFmpeg separately from peak-file conversion, so cold
/// decode latency can be compared with cache load latency on physical devices.
enum WaveformAcquisitionMode {
  compactPeakCache,
  legacyPcmConverted,
  ffmpegCompactBuild,
  eagerPcmCache,
  eagerFfmpeg,
}

class WaveformAcquisitionTimings {
  const WaveformAcquisitionTimings({
    required this.mode,
    this.ffmpeg,
    this.peakReduction,
    this.cacheLoad,
    this.pcmBytes,
  });

  final WaveformAcquisitionMode mode;
  final Duration? ffmpeg;
  final Duration? peakReduction;
  final Duration? cacheLoad;
  /// Input PCM bytes for a fresh extraction/conversion; cache bytes on hit.
  final int? pcmBytes;

  @override
  String toString() =>
      'acquisition=${mode.name}' +
      (ffmpeg == null ? '' : ' ffmpegMs=${ffmpeg!.inMilliseconds}') +
      (peakReduction == null
          ? '' : ' peakMs=${peakReduction!.inMilliseconds}') +
      (cacheLoad == null ? '' : ' cacheMs=${cacheLoad!.inMilliseconds}') +
      (pcmBytes == null ? '' : ' acquisitionBytes=$pcmBytes');
}
