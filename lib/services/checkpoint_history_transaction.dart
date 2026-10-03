import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_policy.dart';
import 'package:subtitle_studio/services/checkpoint_preferences_repository.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_store.dart';
import 'package:subtitle_studio/services/checkpoint_timeline.dart';

class CheckpointMutationPlan {
  final List<SubtitleLine> nextLines;
  final List<SubtitleLineDelta> deltas;
  final bool forceSnapshot;

  const CheckpointMutationPlan({
    required this.nextLines,
    required this.deltas,
    this.forceSnapshot = false,
  });
}

class CheckpointMutationResult {
  final int checkpointId;
  final List<SubtitleLine> persistedLines;

  const CheckpointMutationResult({
    required this.checkpointId,
    required this.persistedLines,
  });
}

/// Atomic working-tree + history transaction.
///
/// New v2 commits use state-after-operation semantics. The collection mutation,
/// checkpoint insert, and single HEAD movement are committed in the same Isar
/// transaction so history cannot claim a mutation that failed (or vice versa).
class CheckpointHistoryTransaction {
  final Isar _isar;
  final CheckpointStore _store;
  final CheckpointPreferencesRepository _preferences;

  CheckpointHistoryTransaction(Isar isar)
      : _isar = isar,
        _store = CheckpointStore(isar),
        _preferences = CheckpointPreferencesRepository(isar);

  Future<CheckpointMutationResult> commit({
    required int sessionId,
    required int subtitleCollectionId,
    required String operationType,
    required String description,
    required CheckpointMutationPlan Function(
      List<SubtitleLine> currentLines,
    ) buildMutation,
    Map<String, dynamic>? metadata,
  }) async {
    final strategy = await _preferences.getCheckpointStrategy();
    final snapshotInterval = await _preferences.getSnapshotInterval();

    late int checkpointId;
    late List<SubtitleLine> persistedLines;

    await _isar.writeTxn(() async {
      final collection =
          await _isar.subtitleCollections.get(subtitleCollectionId);
      if (collection == null) {
        throw StateError(
          'Subtitle collection $subtitleCollectionId was not found.',
        );
      }

      final checkpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .sortByTimestampDesc()
          .findAll();

      final active = checkpoints
          .where((checkpoint) => checkpoint.isActive)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final head = active.isEmpty ? null : active.first;

      final currentLines =
          CheckpointStateReducer.copyLines(collection.lines);
      final plan = buildMutation(
        CheckpointStateReducer.copyLines(currentLines),
      );

      if (plan.deltas.isEmpty) {
        collection.lines =
            CheckpointStateReducer.copyLines(plan.nextLines);
        await _isar.subtitleCollections.put(collection);
        checkpointId = 0;
        persistedLines =
            CheckpointStateReducer.copyLines(collection.lines);
        return;
      }

      final replayed = CheckpointStateReducer.copyLines(currentLines);
      CheckpointStateReducer.applyDeltasStrictInPlace(
        replayed,
        plan.deltas,
      );

      final crossingLegacyBoundary =
          head != null && !CheckpointHistoryMetadata.isPostOperation(head);
      final checkpointsSinceSnapshot =
          CheckpointTimeline.countSinceNearestSnapshot(
        checkpoints: checkpoints,
        fromCheckpointId: head?.id,
      );

      final shouldCreateSnapshot =
          crossingLegacyBoundary ||
          head == null ||
          CheckpointPolicy.shouldCreateSnapshot(
            forceSnapshot: plan.forceSnapshot,
            strategy: strategy,
            checkpointsSinceSnapshot: checkpointsSinceSnapshot,
            snapshotInterval: snapshotInterval,
          );

      if (!shouldCreateSnapshot &&
          !CheckpointStateReducer.samePersistedLines(
            replayed,
            plan.nextLines,
          )) {
        throw const CheckpointIntegrityException(
          'Delta replay does not reproduce the requested post-operation '
          'state. This mutation must use a full snapshot or a richer delta.',
        );
      }

      final checkpoint = Checkpoint(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        timestamp: DateTime.now().toUtc(),
        operationType: operationType,
        description: description,
        parentCheckpointId: head?.id,
        isActive: true,
        checkpointType: shouldCreateSnapshot ? 'snapshot' : 'delta',
        deltas: plan.deltas,
        snapshot: shouldCreateSnapshot
            ? CheckpointStateReducer.copyLines(plan.nextLines)
            : const <SubtitleLine>[],
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          operationMetadata: metadata,
        ),
      );

      for (final checkpoint in active) {
        checkpoint.isActive = false;
      }
      if (active.isNotEmpty) {
        await _isar.checkpoints.putAll(active);
      }

      collection.lines =
          CheckpointStateReducer.copyLines(plan.nextLines);
      await _isar.subtitleCollections.put(collection);
      checkpointId = await _isar.checkpoints.put(checkpoint);
      persistedLines =
          CheckpointStateReducer.copyLines(collection.lines);
    });

    if (checkpointId != 0) {
      await _cleanup(sessionId);
    }

    return CheckpointMutationResult(
      checkpointId: checkpointId,
      persistedLines: persistedLines,
    );
  }

  Future<void> _cleanup(int sessionId) async {
    final maxCheckpoints = await _preferences.getMaxCheckpoints();
    final checkpoints = await _store.getCheckpointsForSession(sessionId);
    final head = await _store.getCurrentHeadCheckpoint(sessionId);

    final toDelete = CheckpointPolicy.cleanupCandidates(
      checkpoints: checkpoints,
      maxCheckpoints: maxCheckpoints,
      headCheckpointId: head?.id,
    );
    if (toDelete.isEmpty) return;

    await _store.deleteCheckpointIds(
      toDelete.map((checkpoint) => checkpoint.id),
    );
  }
}
