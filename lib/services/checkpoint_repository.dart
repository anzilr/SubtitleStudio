import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_manager.dart';

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
