import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

/// Isar-backed checkpoint settings boundary.
///
/// CheckpointManager reads only checkpoint-specific preferences through this
/// repository instead of depending on the legacy static PreferencesModel API.
class CheckpointPreferencesRepository {
  final PreferencesStore _preferencesStore;

  CheckpointPreferencesRepository(Isar isar)
      : _preferencesStore = PreferencesStore(isar);

  Future<Preferences> _getPreferences() {
    return _preferencesStore.getOrCreate();
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
