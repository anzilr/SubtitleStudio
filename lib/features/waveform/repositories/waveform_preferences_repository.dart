import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

/// Isar-backed Waveform preferences.
///
/// Keeps waveform state management independent from the legacy static
/// PreferencesModel/global Isar access.
class WaveformPreferencesRepository {
  final VideoPreferencesStore _videoPreferencesStore;

  WaveformPreferencesRepository(Isar isar)
      : _videoPreferencesStore = VideoPreferencesStore(isar);

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

  Future<Map<String, dynamic>?> getWaveformZoomLevels(
    int subtitleCollectionId,
  ) async {
    final preferences = await _getVideoPreferences(subtitleCollectionId);

    final zoomIndex = preferences.waveformZoomIndex;
    final verticalZoom = preferences.waveformVerticalZoom;
    if (zoomIndex == null || verticalZoom == null) {
      return null;
    }

    return {
      'zoomIndex': zoomIndex,
      'verticalZoom': verticalZoom,
    };
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
