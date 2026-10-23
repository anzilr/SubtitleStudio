import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';
import 'package:subtitle_studio/database/stores/video_preferences_store.dart';

/// Typed preference snapshot used to initialize the Edit-Line screen.
class EditLineStoredPreferences {
  final bool msoneEnabled;
  final bool showOriginalLine;
  final bool autoSaveWithNavigation;
  final bool saveToFileEnabled;
  final bool autoResizeOnKeyboard;
  final int maxLineLength;
  final bool showOriginalTextField;
  final String? videoPath;
  final double editLineResizeRatio;
  final double mobileVideoResizeRatio;
  final String switchLayout;
  final List<String> colorHistory;

  const EditLineStoredPreferences({
    required this.msoneEnabled,
    required this.showOriginalLine,
    required this.autoSaveWithNavigation,
    required this.saveToFileEnabled,
    required this.autoResizeOnKeyboard,
    required this.maxLineLength,
    required this.showOriginalTextField,
    required this.videoPath,
    required this.editLineResizeRatio,
    required this.mobileVideoResizeRatio,
    required this.switchLayout,
    required this.colorHistory,
  });
}

/// Isar-backed preferences used by EditLineRepository.
///
/// This replaces repeated static PreferencesModel calls with an injected,
/// testable dependency and loads initial preferences using one global
/// preferences read plus one per-video preferences read.
class EditLinePreferencesRepository {
  final PreferencesStore _preferencesStore;
  final VideoPreferencesStore _videoPreferencesStore;

  EditLinePreferencesRepository(Isar isar)
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

  Future<EditLineStoredPreferences> load(int subtitleCollectionId) async {
    final results = await Future.wait<Object>([
      _getPreferences(),
      _getVideoPreferences(subtitleCollectionId),
    ]);

    final preferences = results[0] as Preferences;
    final videoPreferences = results[1] as VideoPreferences;

    return EditLineStoredPreferences(
      msoneEnabled: preferences.msoneEnabled,
      showOriginalLine: preferences.showOriginalLine,
      autoSaveWithNavigation: preferences.autoSaveWithNavigation,
      saveToFileEnabled: preferences.saveToFileEnabled,
      autoResizeOnKeyboard: preferences.autoResizeOnKeyboard,
      maxLineLength: preferences.maxLineLength,
      showOriginalTextField: preferences.showOriginalTextField,
      videoPath: videoPreferences.videoPath,
      editLineResizeRatio: preferences.editLineResizeRatio,
      mobileVideoResizeRatio: preferences.mobileVideoResizeRatio,
      switchLayout: preferences.switchLayout,
      colorHistory: List<String>.unmodifiable(preferences.colorHistory),
    );
  }

  Future<bool> savePreference(String key, dynamic value) async {
    switch (key) {
      case 'msoneEnabled':
        await _updatePreferences(
          (preferences) => preferences.msoneEnabled = value as bool,
        );
        return true;
      case 'showOriginalLine':
        await _updatePreferences(
          (preferences) => preferences.showOriginalLine = value as bool,
        );
        return true;
      case 'autoSaveWithNavigation':
        await _updatePreferences(
          (preferences) =>
              preferences.autoSaveWithNavigation = value as bool,
        );
        return true;
      case 'saveToFileEnabled':
        await _updatePreferences(
          (preferences) => preferences.saveToFileEnabled = value as bool,
        );
        return true;
      case 'autoResizeOnKeyboard':
        await _updatePreferences(
          (preferences) => preferences.autoResizeOnKeyboard = value as bool,
        );
        return true;
      case 'maxLineLength':
        await _updatePreferences(
          (preferences) => preferences.maxLineLength = value as int,
        );
        return true;
      case 'showOriginalTextField':
        await _updatePreferences(
          (preferences) => preferences.showOriginalTextField = value as bool,
        );
        return true;
      case 'resizeRatio':
        await _updatePreferences(
          (preferences) => preferences.editLineResizeRatio = value as double,
        );
        return true;
      case 'mobileVideoResizeRatio':
        await _updatePreferences(
          (preferences) =>
              preferences.mobileVideoResizeRatio = value as double,
        );
        return true;
      case 'layoutPreference':
        await _updatePreferences(
          (preferences) => preferences.switchLayout = value as String,
        );
        return true;
      default:
        return false;
    }
  }

  Future<void> saveVideoPath(
    int subtitleCollectionId,
    String path,
  ) async {
    await _updateVideoPreferences(
      subtitleCollectionId,
      (preferences) => preferences.videoPath = path,
    );
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

  Future<void> saveColorHistory(List<String> colorHistory) async {
    await _updatePreferences(
      (preferences) => preferences.colorHistory = colorHistory,
    );
  }
}
