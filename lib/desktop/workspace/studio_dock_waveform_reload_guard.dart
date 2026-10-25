import 'studio_dock_playback_link.dart';

/// Captures the exact media/audio selection that requested a waveform reload.
/// The caller also checks its audio-change revision so a waiting/ready cycle
/// cannot resurrect an obsolete request for the same track.
class StudioDockWaveformReloadSelection {
  const StudioDockWaveformReloadSelection({
    required this.playback,
    required this.videoPath,
    required this.collectionId,
    required this.trackId,
    required this.streamSelector,
  });

  final StudioDockPlaybackLink playback;
  final String videoPath;
  final int collectionId;
  final String? trackId;
  final String? streamSelector;

  bool matches({
    required StudioDockPlaybackLink playback,
    required String videoPath,
    required int collectionId,
  }) {
    final audio = playback.audio.value;
    return identical(this.playback, playback) &&
        this.videoPath == videoPath &&
        this.collectionId == collectionId &&
        audio.status == StudioDockAudioStatus.ready &&
        audio.trackId == trackId &&
        audio.streamSelector == streamSelector;
  }
}

/// Keeps the existing cache/clear/load operations in sequence. In particular,
/// invalidation between clearing the old waveform and starting a new decode
/// must not launch an obsolete FFmpeg audio stream.
class StudioDockWaveformReloadGuard {
  const StudioDockWaveformReloadGuard._();

  static Future<bool> run({
    required bool Function() isCurrent,
    required Future<void> Function() clearCache,
    required Future<void> Function() clearWaveform,
    required Future<void> Function() loadWaveform,
  }) async {
    if (!isCurrent()) return false;
    await clearCache();
    if (!isCurrent()) return false;
    await clearWaveform();
    if (!isCurrent()) return false;
    await loadWaveform();
    return isCurrent();
  }
}
