import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

/// Persistence required by the AI explanation controller.
///
/// This removes the controller's dependency on the legacy static
/// PreferencesModel/global Isar instance.
class AiExplanationPreferencesRepository {
  final PreferencesStore _preferencesStore;

  AiExplanationPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
  }

  Future<String?> getGeminiApiKey() async {
    return (await _getPreferences()).geminiApiKey;
  }

  Future<String> getGeminiModel() async {
    return (await _getPreferences()).geminiModel;
  }

  Future<String?> getAiExplanationPrompt() async {
    return (await _getPreferences()).aiExplanationPrompt;
  }
  Future<int> getAiExplanationContextLines() async {
    return (await _getPreferences()).aiExplanationContextLines ?? 3;
  }

  Future<void> setAiExplanationPrompt(String? value) async {
    await _updatePreferences((preferences) {
      preferences.aiExplanationPrompt = value;
    });
  }

  Future<void> setAiExplanationContextLines(int value) async {
    await _updatePreferences((preferences) {
      preferences.aiExplanationContextLines = value;
    });
  }

  Future<void> setGeminiModel(String value) async {
    await _updatePreferences((preferences) {
      preferences.geminiModel = value;
    });
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) {
    return _preferencesStore.update(update);
  }

}
