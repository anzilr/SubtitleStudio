import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_manager.dart';
import 'package:subtitle_studio/services/checkpoint_history_validator.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';

/// Injectable checkpoint boundary used by migrated repositories.
///
/// Checkpoint algorithms and persistence are owned by an Isar-injected
/// CheckpointManager instance.
class CheckpointRepository {
  final CheckpointManager _manager;

  CheckpointRepository(Isar isar) : _manager = CheckpointManager(isar);

  Future<int> createInitialSnapshot({
    required int sessionId,
    required int subtitleCollectionId,
  }) {
    return _manager.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
    );
  }

  Future<List<Checkpoint>> getCheckpointsForSession(int sessionId) {
    return _manager.getCheckpointsForSession(sessionId);
  }

  Future<bool> checkoutCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) {
    return _manager.checkoutCheckpoint(
      checkpointId: checkpointId,
      sessionId: sessionId,
    );
  }

  Future<bool> undoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) {
    return checkoutCheckpoint(
      checkpointId: checkpointId,
      sessionId: sessionId,
    );
  }

  Future<Checkpoint?> getHeadCheckpoint(int sessionId) {
    return _manager.getHeadCheckpoint(sessionId);
  }

  /// Dry-run the legacy/V2 ref migration; persistence is intentionally deferred.
  Future<CheckpointReferenceMigrationPlan> previewReferenceMigration(
    int sessionId,
  ) {
    return _manager.previewReferenceMigration(sessionId);
  }

  Future<List<CheckpointReference>> getReferencesForSession(int sessionId) {
    return _manager.getReferencesForSession(sessionId);
  }

  Future<HistoryRef> createBranch({
    required int sessionId,
    required String name,
    required int checkpointId,
  }) => _manager.createBranch(
    sessionId: sessionId, name: name, checkpointId: checkpointId,
  );

  Future<HistoryRef> createBookmark({
    required int sessionId,
    required String name,
    required int checkpointId,
  }) => _manager.createBookmark(
    sessionId: sessionId, name: name, checkpointId: checkpointId,
  );

  Future<void> renameReference({
    required int sessionId,
    required String name,
    required String newName,
  }) => _manager.renameReference(
    sessionId: sessionId, name: name, newName: newName,
  );

  Future<void> deleteReference({
    required int sessionId,
    required String name,
  }) => _manager.deleteReference(sessionId: sessionId, name: name);

  Future<bool> checkoutBranch({
    required int sessionId,
    required String name,
  }) => _manager.checkoutBranch(sessionId: sessionId, name: name);

  Future<List<HistoryRef>> getPersistentReferences(int sessionId) =>
      _manager.getPersistentReferences(sessionId);

  Future<CheckpointHistoryHealth> validateHistory(int sessionId) {
    return _manager.validateHistory(sessionId);
  }

  Future<bool> undo({required int sessionId}) {
    return _manager.undo(sessionId: sessionId);
  }

  Future<List<Checkpoint>> getRedoOptions(int sessionId) {
    return _manager.getRedoOptions(sessionId);
  }

  Future<bool> redoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) {
    return _manager.redoToCheckpoint(
      checkpointId: checkpointId,
      sessionId: sessionId,
    );
  }

  Future<int> createManualCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    String? customDescription,
  }) {
    return _manager.createManualCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      customDescription: customDescription,
    );
  }

}
