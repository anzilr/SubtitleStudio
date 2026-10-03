import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

class AppSettingsSnapshot {
  final bool msoneEnabled;
  final bool saveToFileEnabled;
  final int maxLineLength;
  final int skipDurationSeconds;
  final String switchLayout;
  final int maxCheckpoints;
  final int snapshotInterval;
  final String checkpointStrategy;
  final String? geminiApiKey;
  final String geminiModel;
  final int waveformMaxPixels;
  final int waveformSampleRateFactor;
  final double waveformZoomMultiplier;

  const AppSettingsSnapshot({
    required this.msoneEnabled,
    required this.saveToFileEnabled,
    required this.maxLineLength,
    required this.skipDurationSeconds,
    required this.switchLayout,
    required this.maxCheckpoints,
    required this.snapshotInterval,
    required this.checkpointStrategy,
    required this.geminiApiKey,
    required this.geminiModel,
    required this.waveformMaxPixels,
    required this.waveformSampleRateFactor,
    required this.waveformZoomMultiplier,
  });
}

class TranslatorProfile {
  final String? name;
  final String? email;
  final String? contactId;

  const TranslatorProfile({
    this.name,
    this.email,
    this.contactId,
  });
}

/// Isar-backed application preference persistence shared by Settings and
/// non-editor screens.
///
/// This intentionally keeps the existing schema and defaults unchanged while
/// removing static PreferencesModel/global-Isar access from UI code.
class AppPreferencesRepository {
  final PreferencesStore _preferencesStore;

  AppPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) {
    return _preferencesStore.update(update);
  }

  Future<AppSettingsSnapshot> loadSettings() async {
    final preferences = await _getPreferences();

    return AppSettingsSnapshot(
      msoneEnabled: preferences.msoneEnabled,
      saveToFileEnabled: preferences.saveToFileEnabled,
      maxLineLength: preferences.maxLineLength,
      skipDurationSeconds: preferences.skipDurationSeconds,
      switchLayout: preferences.switchLayout,
      maxCheckpoints: preferences.maxCheckpoints,
      snapshotInterval: preferences.snapshotInterval,
      checkpointStrategy: preferences.checkpointStrategy,
      geminiApiKey: preferences.geminiApiKey,
      geminiModel: preferences.geminiModel,
      waveformMaxPixels: preferences.waveformMaxPixels ?? 500000,
      waveformSampleRateFactor:
          preferences.waveformSampleRateFactor ?? 16,
      // Preserve PreferencesModel's existing fallback behavior.
      waveformZoomMultiplier: preferences.waveformZoomMultiplier ?? 1.25,
    );
  }

  Future<TranslatorProfile> loadTranslatorProfile() async {
    final preferences = await _getPreferences();
    return TranslatorProfile(
      name: preferences.translatorName,
      email: preferences.translatorEmail,
      contactId: preferences.translatorContactId,
    );
  }

  Future<void> saveTranslatorProfile({
    required String name,
    required String email,
    required String contactId,
  }) async {
    await _updatePreferences((preferences) {
      preferences.translatorName = name;
      preferences.translatorEmail = email;
      preferences.translatorContactId = contactId;
    });
  }

  Future<void> setMsoneEnabled(bool value) =>
      _updatePreferences((p) => p.msoneEnabled = value);

  Future<void> setSaveToFileEnabled(bool value) =>
      _updatePreferences((p) => p.saveToFileEnabled = value);

  Future<void> setMaxLineLength(int value) =>
      _updatePreferences((p) => p.maxLineLength = value);

  Future<void> setSkipDurationSeconds(int value) =>
      _updatePreferences((p) => p.skipDurationSeconds = value);

  Future<void> setSwitchLayout(String value) =>
      _updatePreferences((p) => p.switchLayout = value);

  Future<void> setMaxCheckpoints(int value) =>
      _updatePreferences((p) => p.maxCheckpoints = value);

  Future<void> setSnapshotInterval(int value) =>
      _updatePreferences((p) => p.snapshotInterval = value);

  Future<void> setCheckpointStrategy(String value) =>
      _updatePreferences((p) => p.checkpointStrategy = value);

  Future<void> setGeminiApiKey(String? value) =>
      _updatePreferences((p) => p.geminiApiKey = value);

  Future<void> setGeminiModel(String value) =>
      _updatePreferences((p) => p.geminiModel = value);

  Future<void> setWaveformMaxPixels(int value) =>
      _updatePreferences((p) => p.waveformMaxPixels = value);

  Future<void> setWaveformSampleRateFactor(int value) =>
      _updatePreferences((p) => p.waveformSampleRateFactor = value);

  Future<void> setWaveformZoomMultiplier(double value) =>
      _updatePreferences((p) => p.waveformZoomMultiplier = value);

  Future<void> resetWaveformSettings() async {
    await _updatePreferences((preferences) {
      preferences.waveformMaxPixels = 500000;
      preferences.waveformSampleRateFactor = 16;
      preferences.waveformZoomMultiplier = 1.35;
    });
  }

  Future<void> clearAllPreferences() {
    return _preferencesStore.clear();
  }
  Future<bool> getShowAllComments() async {
    return (await _getPreferences()).showAllComments;
  }

  Future<void> setShowAllComments(bool value) =>
      _updatePreferences((p) => p.showAllComments = value);


  Future<String?> getOlamLastUpdateDate() async {
    return (await _getPreferences()).olamLastUpdateDate;
  }

  Future<void> setOlamLastUpdateDate(String value) =>
      _updatePreferences((p) => p.olamLastUpdateDate = value);

  Future<bool> getOlamWholeWordSearch() async {
    return (await _getPreferences()).olamWholeWordSearch;
  }

  Future<void> setOlamWholeWordSearch(bool value) =>
      _updatePreferences((p) => p.olamWholeWordSearch = value);

  Future<bool> getOlamCaseSensitiveSearch() async {
    return (await _getPreferences()).olamCaseSensitiveSearch;
  }

  Future<void> setOlamCaseSensitiveSearch(bool value) =>
      _updatePreferences((p) => p.olamCaseSensitiveSearch = value);


}
