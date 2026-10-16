import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

/// One read of the old and new settings, so startup cannot mix snapshots.
class ThemePreferenceSnapshot {
  const ThemePreferenceSnapshot({
    this.exists = false,
    this.skinId,
    this.themeMode,
    this.fontPath,
    this.fontName,
  });

  final bool exists;
  final String? skinId;
  final String? themeMode;
  final String? fontPath;
  final String? fontName;
}

/// Small injectable boundary for testing startup races without opening Isar.
abstract interface class ThemePreferencesStore {
  Future<ThemePreferenceSnapshot> load();
  Future<void> saveThemeMode(String mode);
  Future<void> saveSkinId(String skinId);
  Future<void> setAppFontPath(String? path);
  Future<void> setAppFontName(String? name);
}

/// Isar-backed persistence for the Riverpod theme controller.
class ThemePreferencesRepository implements ThemePreferencesStore {
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

  @override
  Future<ThemePreferenceSnapshot> load() async {
    final prefs = await _preferencesStore.findFirst();
    if (prefs == null) return const ThemePreferenceSnapshot();
    return ThemePreferenceSnapshot(
      exists: true,
      skinId: prefs.skinId,
      themeMode: prefs.themeMode,
      fontPath: prefs.appFontPath,
      fontName: prefs.appFontName,
    );
  }

  @override
  Future<void> saveSkinId(String skinId) async {
    await _updatePreferences(
      (preferences) => preferences.skinId = skinId,
    );
  }

  Future<String?> getThemeMode() async {
    return (await _preferencesStore.findFirst())?.themeMode;
  }

  @override
  Future<void> saveThemeMode(String themeMode) async {
    await _updatePreferences(
      (preferences) => preferences.themeMode = themeMode,
    );
  }

  Future<String?> getAppFontPath() async {
    return (await _getPreferences()).appFontPath;
  }

  @override
  Future<void> setAppFontPath(String? path) async {
    await _updatePreferences(
      (preferences) => preferences.appFontPath = path,
    );
  }

  Future<String?> getAppFontName() async {
    return (await _getPreferences()).appFontName;
  }

  @override
  Future<void> setAppFontName(String? name) async {
    await _updatePreferences(
      (preferences) => preferences.appFontName = name,
    );
  }
}
