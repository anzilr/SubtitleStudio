import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

/// Isar-backed persistence used by the main Editor's video/layout repository.
///
/// Keeping these operations behind an injected repository removes the Editor's
/// dependency on the legacy static PreferencesModel/global Isar access.
class EditorPreferencesRepository {
  final PreferencesStore _preferencesStore;
  final VideoPreferencesStore _videoPreferencesStore;

  EditorPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar),
        _videoPreferencesStore = VideoPreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) {
    return _preferencesStore.update(update);
  }

  Future<VideoPreferences> getVideoPreferences(
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

  Future<String?> getVideoPath(int subtitleCollectionId) async {
    return (await getVideoPreferences(subtitleCollectionId)).videoPath;
  }

  Future<void> saveVideoPath(
    int subtitleCollectionId,
    String path, {
    String? macOsBookmark,
  }) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.videoPath = path;
      preferences.macOsBookmark = macOsBookmark;
    });
  }

  Future<void> removeVideoPath(int subtitleCollectionId) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.videoPath = null;
      preferences.macOsBookmark = null;
      preferences.selectedAudioTrackId = null;
      preferences.selectedAudioTrackTitle = null;
      preferences.selectedAudioTrackLanguage = null;
      preferences.waveformPcmPath = null;
      preferences.waveformSampleRate = null;
      preferences.waveformTotalSamples = null;
      preferences.waveformChannels = null;
      preferences.waveformGeneratedAt = null;
    });
  }

  Future<String?> getSecondarySubtitlePath(
    int subtitleCollectionId,
  ) async {
    return (await getVideoPreferences(subtitleCollectionId))
        .secondarySubtitlePath;
  }

  Future<void> saveSecondarySubtitlePath(
    int subtitleCollectionId,
    String path,
  ) async {
    await _updateVideoPreferences(
      subtitleCollectionId,
      (preferences) => preferences.secondarySubtitlePath = path,
    );
  }

  Future<void> removeSecondarySubtitlePath(
    int subtitleCollectionId,
  ) async {
    await _updateVideoPreferences(
      subtitleCollectionId,
      (preferences) => preferences.secondarySubtitlePath = null,
    );
  }

  Future<bool> getSecondaryIsOriginal(int subtitleCollectionId) async {
    return (await getVideoPreferences(subtitleCollectionId))
        .secondaryIsOriginal;
  }

  Future<void> setSecondaryIsOriginal(
    int subtitleCollectionId,
    bool value,
  ) async {
    await _updateVideoPreferences(
      subtitleCollectionId,
      (preferences) => preferences.secondaryIsOriginal = value,
    );
  }

  Future<bool> getFloatingControlsEnabled() async {
    return (await _getPreferences()).floatingControlsEnabled;
  }

  Future<void> setFloatingControlsEnabled(bool value) async {
    await _updatePreferences(
      (preferences) => preferences.floatingControlsEnabled = value,
    );
  }

  Future<bool> getMsoneEnabled() async {
    return (await _getPreferences()).msoneEnabled;
  }

  Future<void> setMsoneEnabled(bool value) async {
    await _updatePreferences(
      (preferences) => preferences.msoneEnabled = value,
    );
  }

  Future<String> getSwitchLayout() async {
    return (await _getPreferences()).switchLayout;
  }

  Future<void> setSwitchLayout(String value) async {
    await _updatePreferences(
      (preferences) => preferences.switchLayout = value,
    );
  }

  Future<double> getEditScreenResizeRatio() async {
    return (await _getPreferences()).editScreenResizeRatio;
  }

  Future<void> setEditScreenResizeRatio(double value) async {
    await _updatePreferences(
      (preferences) => preferences.editScreenResizeRatio = value,
    );
  }

  Future<double> getMobileVideoResizeRatio() async {
    return (await _getPreferences()).mobileVideoResizeRatio;
  }

  Future<void> setMobileVideoResizeRatio(double value) async {
    await _updatePreferences(
      (preferences) => preferences.mobileVideoResizeRatio = value,
    );
  }

  /// Clear cached waveform metadata for a subtitle collection.
  Future<void> clearWaveformCache(int subtitleCollectionId) async {
    await _updateVideoPreferences(subtitleCollectionId, (preferences) {
      preferences.waveformPcmPath = null;
      preferences.waveformSampleRate = null;
      preferences.waveformTotalSamples = null;
      preferences.waveformChannels = null;
      preferences.waveformGeneratedAt = null;
    });
  }

}
