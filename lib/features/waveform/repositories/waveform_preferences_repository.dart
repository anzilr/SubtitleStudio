import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Isar-backed Waveform preferences.
///
/// Keeps waveform state management independent from the legacy static
/// PreferencesModel/global Isar access.
class WaveformPreferencesRepository {
  final Isar _isar;

  const WaveformPreferencesRepository(this._isar);

  Future<VideoPreferences> _getVideoPreferences(
    int subtitleCollectionId,
  ) async {
    final existing = await _isar.videoPreferences
        .filter()
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .findFirst();

    if (existing != null) return existing;

    final created = VideoPreferences(
      subtitleCollectionId: subtitleCollectionId,
    );
    await _isar.writeTxn(() async {
      await _isar.videoPreferences.put(created);
    });
    return created;
  }

  Future<void> _updateVideoPreferences(
    int subtitleCollectionId,
    void Function(VideoPreferences preferences) update,
  ) async {
    final existing = await _isar.videoPreferences
        .filter()
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .findFirst();
    final preferences = existing ??
        VideoPreferences(subtitleCollectionId: subtitleCollectionId);

    update(preferences);

    await _isar.writeTxn(() async {
      await _isar.videoPreferences.put(preferences);
    });
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
