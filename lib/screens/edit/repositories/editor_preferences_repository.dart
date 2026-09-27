import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Isar-backed persistence used by the main Editor's video/layout repository.
///
/// Keeping these operations behind an injected repository removes the Editor's
/// dependency on the legacy static PreferencesModel/global Isar access.
class EditorPreferencesRepository {
  final Isar _isar;

  const EditorPreferencesRepository(this._isar);

  Future<Preferences> _getPreferences() async {
    final existing = await _isar.preferences.where().findFirst();
    if (existing != null) return existing;

    final created = Preferences(autoSave: true);
    await _isar.writeTxn(() async {
      await _isar.preferences.put(created);
    });
    return created;
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) async {
    final existing = await _isar.preferences.where().findFirst();
    final preferences = existing ?? Preferences(autoSave: true);
    update(preferences);

    await _isar.writeTxn(() async {
      await _isar.preferences.put(preferences);
    });
  }

  Future<VideoPreferences> getVideoPreferences(
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
}
