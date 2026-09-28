import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_manager.dart';

/// Injectable checkpoint boundary used by migrated repositories.
///
/// The legacy CheckpointManager still owns the checkpoint algorithm and global
/// persistence internally. Keeping that implementation behind this facade lets
/// feature repositories stop depending on static global APIs now, while the
/// storage/policy split can be completed in a later, separately tested phase.
class CheckpointRepository {
  const CheckpointRepository();

  Future<int> createInitialSnapshot({
    required int sessionId,
    required int subtitleCollectionId,
  }) {
    return CheckpointManager.createInitialSnapshot(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
    );
  }

  Future<int> createEditCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    required SubtitleLine beforeLine,
    required SubtitleLine afterLine,
  }) {
    return CheckpointManager.createEditCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      beforeLine: beforeLine,
      afterLine: afterLine,
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
    return CheckpointManager.createCheckpoint(
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
    return CheckpointManager.getCheckpointsForSession(sessionId);
  }

  Future<bool> undoToCheckpoint({
    required int checkpointId,
    required int sessionId,
  }) {
    return CheckpointManager.undoToCheckpoint(
      checkpointId: checkpointId,
      sessionId: sessionId,
    );
  }

  Future<int> createManualCheckpoint({
    required int sessionId,
    required int subtitleCollectionId,
    String? customDescription,
  }) {
    return CheckpointManager.createManualCheckpoint(
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
    return CheckpointManager.createDeleteCheckpoint(
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
    return CheckpointManager.createAddCheckpoint(
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
    return CheckpointManager.createSplitCheckpoint(
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
    return CheckpointManager.createMergeCheckpoint(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      firstLine: firstLine,
      secondLine: secondLine,
      mergedLine: mergedLine,
      preOperationState: preOperationState,
    );
  }

}
