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
}
