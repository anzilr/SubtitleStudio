import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Isar-backed persistence for the Riverpod theme controller.
class ThemePreferencesRepository {
  final Isar _isar;

  const ThemePreferencesRepository(this._isar);

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

  Future<String?> getThemeMode() async {
    return (await _isar.preferences.where().findFirst())?.themeMode;
  }

  Future<void> saveThemeMode(String themeMode) async {
    await _updatePreferences(
      (preferences) => preferences.themeMode = themeMode,
    );
  }

  Future<String?> getAppFontPath() async {
    return (await _getPreferences()).appFontPath;
  }

  Future<void> setAppFontPath(String? path) async {
    await _updatePreferences(
      (preferences) => preferences.appFontPath = path,
    );
  }

  Future<String?> getAppFontName() async {
    return (await _getPreferences()).appFontName;
  }

  Future<void> setAppFontName(String? name) async {
    await _updatePreferences(
      (preferences) => preferences.appFontName = name,
    );
  }
}
