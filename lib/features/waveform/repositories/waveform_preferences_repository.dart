import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

class WaveformZoomPreferences {
  final int zoomIndex;
  final double verticalZoom;

  const WaveformZoomPreferences({
    required this.zoomIndex,
    required this.verticalZoom,
  });
}

class WaveformCacheMetadata {
  final String pcmPath;
  final int sampleRate;
  final int totalSamples;
  final int channels;
  final DateTime? generatedAt;

  const WaveformCacheMetadata({
    required this.pcmPath,
    required this.sampleRate,
    required this.totalSamples,
    required this.channels,
    this.generatedAt,
  });
}

class WaveformGenerationConfig {
  final int maxPixelsForDetailedView;
  final int sampleRateFactor;
  final double zoomMultiplier;

  const WaveformGenerationConfig({
    required this.maxPixelsForDetailedView,
    required this.sampleRateFactor,
    required this.zoomMultiplier,
  });
}

/// Isar-backed Waveform persistence.
///
/// Global waveform generation settings live in [Preferences], while cache,
/// selected-track, and zoom state are scoped to a subtitle collection through
/// [VideoPreferences].
class WaveformPreferencesRepository {
  final PreferencesStore _preferencesStore;
  final VideoPreferencesStore _videoPreferencesStore;

  WaveformPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar),
        _videoPreferencesStore = VideoPreferencesStore(isar);

  Future<VideoPreferences> _getVideoPreferences(
    int subtitleCollectionId,
  ) {
    return _videoPreferencesStore.getOrCreate(subtitleCollectionId);
  }

  Future<void> _updateVideoPreferences(
    int subtitleCollectionId,
    void Function(VideoPreferences preferences) update,
  ) {
    return _videoPreferencesStore.update(subtitleCollectionId, update);
  }

  Future<String?> getSelectedAudioTrackId(
    int subtitleCollectionId,
  ) async {
    return (await _getVideoPreferences(subtitleCollectionId))
        .selectedAudioTrackId;
  }

  Future<WaveformGenerationConfig> getGenerationConfig() async {
    final preferences = await _preferencesStore.getOrCreate();
    return WaveformGenerationConfig(
      maxPixelsForDetailedView: preferences.waveformMaxPixels ?? 500000,
      sampleRateFactor: preferences.waveformSampleRateFactor ?? 16,
      // Preserve the legacy PreferencesModel fallback.
      zoomMultiplier: preferences.waveformZoomMultiplier ?? 1.25,
    );
  }

  Future<WaveformCacheMetadata?> getWaveformCache(
    int subtitleCollectionId,
  ) async {
    final preferences = await _getVideoPreferences(subtitleCollectionId);

    final pcmPath = preferences.waveformPcmPath;
    final sampleRate = preferences.waveformSampleRate;
    final totalSamples = preferences.waveformTotalSamples;
    final channels = preferences.waveformChannels;
    if (pcmPath == null ||
        sampleRate == null ||
        totalSamples == null ||
        channels == null) {
      return null;
    }

    return WaveformCacheMetadata(
      pcmPath: pcmPath,
      sampleRate: sampleRate,
      totalSamples: totalSamples,
      channels: channels,
      generatedAt: preferences.waveformGeneratedAt,
    );
  }

  Future<void> saveWaveformCache({
    required int subtitleCollectionId,
    required String pcmPath,
    required int sampleRate,
    required int totalSamples,
    required int channels,
  }) {
    return _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.waveformPcmPath = pcmPath;
      preferences.waveformSampleRate = sampleRate;
      preferences.waveformTotalSamples = totalSamples;
      preferences.waveformChannels = channels;
      preferences.waveformGeneratedAt = DateTime.now();
    });
  }

  Future<void> clearWaveformCache(int subtitleCollectionId) {
    return _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.waveformPcmPath = null;
      preferences.waveformSampleRate = null;
      preferences.waveformTotalSamples = null;
      preferences.waveformChannels = null;
      preferences.waveformGeneratedAt = null;
    });
  }

  Future<WaveformZoomPreferences?> getWaveformZoomLevels(
    int subtitleCollectionId,
  ) async {
    final preferences = await _getVideoPreferences(subtitleCollectionId);

    final zoomIndex = preferences.waveformZoomIndex;
    final verticalZoom = preferences.waveformVerticalZoom;
    if (zoomIndex == null || verticalZoom == null) {
      return null;
    }

    return WaveformZoomPreferences(
      zoomIndex: zoomIndex,
      verticalZoom: verticalZoom,
    );
  }

  Future<void> saveWaveformZoomLevels({
    required int subtitleCollectionId,
    required int zoomIndex,
    required double verticalZoom,
  }) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.waveformZoomIndex = zoomIndex;
      preferences.waveformVerticalZoom = verticalZoom;
    });
  }
}
