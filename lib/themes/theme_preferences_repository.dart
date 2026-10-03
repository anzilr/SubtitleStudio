import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

/// Isar-backed persistence for the Riverpod theme controller.
class ThemePreferencesRepository {
  final PreferencesStore _preferencesStore;

  ThemePreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
  }

  Future<void> _updatePreferences(
    void Function(Preferences preferences) update,
  ) {
    return _preferencesStore.update(update);
  }

  Future<String?> getThemeMode() async {
    return (await _preferencesStore.getOrCreate()).themeMode;
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
