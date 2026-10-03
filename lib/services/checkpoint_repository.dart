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

  Future<int> createEditCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine beforeLine,
    required SubtitleLine afterLine,
    List<SubtitleLine>? preOperationState,
  }) {
    return _manager.createEditCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      beforeLine: beforeLine,
      afterLine: afterLine,
      preOperationState: preOperationState,
    );
  }

  Future<int> createCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required String operationType,
    required String description,
    required List<SubtitleLineDelta> deltas,
    Map<String, dynamic>? metadata,
    bool forceSnapshot = false,
    List<SubtitleLine>? preOperationState,
  }) {
    return _manager.createCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: operationType,
      description: description,
      deltas: deltas,
      metadata: metadata,
      forceSnapshot: forceSnapshot,
      preOperationState: preOperationState,
    );
  }
  Future<List<Checkpoint>> getCheckpointsForSession(int sessionId) {
    return _manager.getCheckpointsForSession(sessionId);
  }

  Future<bool> undoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) {
    return _manager.undoToCheckpoint(
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

  Future<int> createDeleteCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine deletedLine,
    required int deletedIndex,
  }) {
    return _manager.createDeleteCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      deletedLine: deletedLine,
      deletedIndex: deletedIndex,
    );
  }

  Future<int> createAddCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine addedLine,
    required int insertIndex,
    List<SubtitleLine>? preOperationState,
  }) {
    return _manager.createAddCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      addedLine: addedLine,
      insertIndex: insertIndex,
      preOperationState: preOperationState,
    );
  }

  Future<int> createSplitCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine originalLine,
    required SubtitleLine firstPart,
    required SubtitleLine secondPart,
    List<SubtitleLine>? preOperationState,
  }) {
    return _manager.createSplitCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      originalLine: originalLine,
      firstPart: firstPart,
      secondPart: secondPart,
      preOperationState: preOperationState,
    );
  }

  Future<int> createMergeCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine firstLine,
    required SubtitleLine secondLine,
    required SubtitleLine mergedLine,
    List<SubtitleLine>? preOperationState,
  }) {
    return _manager.createMergeCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      firstLine: firstLine,
      secondLine: secondLine,
      mergedLine: mergedLine,
      preOperationState: preOperationState,
    );
  }

}
