import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_policy.dart';
import 'package:subtitle_studio/services/checkpoint_preferences_repository.dart';
import 'package:subtitle_studio/services/checkpoint_reconstructor.dart';
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

      final currentLines =
          CheckpointStateReducer.copyLines(collection.lines);

      Checkpoint? head;
      if (active.isEmpty) {
        if (checkpoints.isEmpty) {
          final root = Checkpoint(
            sessionId: sessionId,
            subtitleCollectionId: subtitleCollectionId,
            timestamp: DateTime.now().toUtc(),
            operationType: 'snapshot',
            description: 'Initial state',
            parentCheckpointId: null,
            isActive: true,
            checkpointType: 'snapshot',
            deltas: const <SubtitleLineDelta>[],
            snapshot: CheckpointStateReducer.copyLines(currentLines),
            metadata: CheckpointHistoryMetadata.encodePostOperation(
              operationMetadata: {
                'reason': 'auto-initial',
                'system': true,
                'lineCount': currentLines.length,
              },
            ),
          );
          root.id = await _isar.checkpoints.put(root);
          checkpoints.add(root);
          active.add(root);
          head = root;
        } else {
          final containsV2 = checkpoints.any(
            CheckpointHistoryMetadata.isPostOperation,
          );
          if (containsV2) {
            throw const CheckpointIntegrityException(
              'V2 checkpoint history contains commits but has no HEAD.',
            );
          }

          // Compatibility repair for legacy history that lost its active flag.
          // The next v2 commit is forced to a snapshot boundary.
          head = checkpoints.first;
        }
      } else {
        final activeV2 = active.where(
          CheckpointHistoryMetadata.isPostOperation,
        );
        if (active.length > 1 && activeV2.isNotEmpty) {
          throw const CheckpointIntegrityException(
            'V2 checkpoint history contains more than one HEAD.',
          );
        }
        head = active.first;
      }

      if (CheckpointHistoryMetadata.isPostOperation(head)) {
        final representedHeadState =
            CheckpointReconstructor.reconstructPostOperation(
          checkpoints: checkpoints,
          targetCheckpointId: head.id,
        );

        if (!CheckpointStateReducer.samePersistedLines(
          representedHeadState,
          currentLines,
        )) {
          final syncCheckpoint = Checkpoint(
            sessionId: sessionId,
            subtitleCollectionId: subtitleCollectionId,
            timestamp: DateTime.now().toUtc(),
            operationType: 'sync',
            description: 'Captured external subtitle changes',
            parentCheckpointId: head.id,
            isActive: true,
            checkpointType: 'snapshot',
            deltas: const <SubtitleLineDelta>[],
            snapshot: CheckpointStateReducer.copyLines(currentLines),
            metadata: CheckpointHistoryMetadata.encodePostOperation(
              operationMetadata: const {
                'reason': 'working-tree-sync',
                'system': true,
              },
            ),
          );

          for (final checkpoint in active) {
            checkpoint.isActive = false;
          }
          if (active.isNotEmpty) {
            await _isar.checkpoints.putAll(active);
          }

          syncCheckpoint.id =
              await _isar.checkpoints.put(syncCheckpoint);
          checkpoints.add(syncCheckpoint);
          active
            ..clear()
            ..add(syncCheckpoint);
          head = syncCheckpoint;
        }
      }

      final plan = buildMutation(
        CheckpointStateReducer.copyLines(currentLines),
      );

      if (plan.deltas.isEmpty) {
        if (!CheckpointStateReducer.samePersistedLines(
          currentLines,
          plan.nextLines,
        )) {
          throw const CheckpointIntegrityException(
            'A history mutation changed subtitle state without recording '
            'deltas.',
          );
        }

        checkpointId = 0;
        persistedLines =
            CheckpointStateReducer.copyLines(currentLines);
        return;
      }

      final replayed = CheckpointStateReducer.copyLines(currentLines);
      CheckpointStateReducer.applyDeltasStrictInPlace(
        replayed,
        plan.deltas,
      );

      final crossingLegacyBoundary =
          !CheckpointHistoryMetadata.isPostOperation(head);
      final checkpointsSinceSnapshot =
          CheckpointTimeline.countSinceNearestSnapshot(
        checkpoints: checkpoints,
        fromCheckpointId: head.id,
      );

      final shouldCreateSnapshot =
          crossingLegacyBoundary ||
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
        parentCheckpointId: head.id,
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

      for (final existing in active) {
        existing.isActive = false;
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
