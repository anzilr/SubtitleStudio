import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Low-level persistence boundary for the process-wide [Preferences] record.
///
/// The application treats Preferences as a singleton even though the legacy
/// schema uses an auto-increment ID. Keeping the read/create/update sequence
/// inside one Isar write transaction makes that invariant explicit for all
/// migrated repositories and prevents concurrent "find none -> create" paths.
class PreferencesStore {
  final Isar _isar;

  const PreferencesStore(this._isar);

  Future<Preferences> getOrCreate() async {
    final existing = await _isar.preferences.where().findFirst();
    if (existing != null) return existing;

    late Preferences preferences;
    await _isar.writeTxn(() async {
      preferences = await _isar.preferences.where().findFirst() ??
          Preferences(autoSave: true);

      if (preferences.id == Isar.autoIncrement) {
        await _isar.preferences.put(preferences);
      }
    });

    return preferences;
  }

  Future<void> update(
    void Function(Preferences preferences) update,
  ) async {
    await _isar.writeTxn(() async {
      final preferences = await _isar.preferences.where().findFirst() ??
          Preferences(autoSave: true);

      update(preferences);
      await _isar.preferences.put(preferences);
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.preferences.clear();
    });
  }
}
