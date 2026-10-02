import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Isar-backed checkpoint settings boundary.
///
/// CheckpointManager reads only checkpoint-specific preferences through this
/// repository instead of depending on the legacy static PreferencesModel API.
class CheckpointPreferencesRepository {
  final Isar _isar;

  const CheckpointPreferencesRepository(this._isar);

  Future<Preferences> _getPreferences() async {
    final existing = await _isar.preferences.where().findFirst();
    if (existing != null) return existing;

    final created = Preferences(autoSave: true);
    await _isar.writeTxn(() async {
      await _isar.preferences.put(created);
    });
    return created;
  }

  Future<int> getMaxCheckpoints() async {
    return (await _getPreferences()).maxCheckpoints;
  }

  Future<int> getSnapshotInterval() async {
    return (await _getPreferences()).snapshotInterval;
  }

  Future<String> getCheckpointStrategy() async {
    return (await _getPreferences()).checkpointStrategy;
  }
}
