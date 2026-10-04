import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

/// Persistence boundary for FilePickerSAF's desktop last-directory hint.
///
/// FilePickerSAF remains a static platform utility for now, but no longer
/// reaches through PreferencesModel or the global Isar handle.
class FilePickerPreferencesRepository {
  final PreferencesStore _preferencesStore;

  FilePickerPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar);

  Future<String?> getLastUsedDirectory() async {
    return (await _preferencesStore.getOrCreate()).lastUsedDirectory;
  }

  Future<void> setLastUsedDirectory(String? path) {
    return _preferencesStore.update(
      (preferences) => preferences.lastUsedDirectory = path,
    );
  }
}
