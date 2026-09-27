import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Persistence required by the AI explanation controller.
///
/// This removes the controller's dependency on the legacy static
/// PreferencesModel/global Isar instance.
class AiExplanationPreferencesRepository {
  final Isar _isar;

  const AiExplanationPreferencesRepository(this._isar);

  Future<Preferences> _getPreferences() async {
    final existing = await _isar.preferences.where().findFirst();
    if (existing != null) return existing;

    final created = Preferences(autoSave: true);
    await _isar.writeTxn(() async {
      await _isar.preferences.put(created);
    });
    return created;
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
}
