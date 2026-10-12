import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Low-level Isar persistence boundary for checkpoint history.
///
/// This store owns checkpoint/collection queries and atomic writes only.
/// Checkpoint policy, branching decisions, reconstruction, and user-facing
/// orchestration remain in CheckpointManager and the pure checkpoint helpers.
class CheckpointConcurrentModificationException implements Exception {
  final int? expectedHeadId;
  final int? actualHeadId;

  const CheckpointConcurrentModificationException({
    required this.expectedHeadId,
    required this.actualHeadId,
  });

  @override
  String toString() {
    return 'CheckpointConcurrentModificationException: '
        'expected HEAD $expectedHeadId, actual HEAD $actualHeadId';
  }
}

class CheckpointStore {
  final Isar _isar;

  const CheckpointStore(this._isar);

  Future<SubtitleCollection?> getSubtitleCollection(int collectionId) {
    return _isar.subtitleCollections.get(collectionId);
  }

  Future<Checkpoint?> getCheckpoint(int checkpointId) {
    return _isar.checkpoints.get(checkpointId);
  }

  Future<Checkpoint?> findInitialSnapshot({
    required int sessionId,
    required int subtitleCollectionId,
  }) {
    return _isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .subtitleCollectionIdEqualTo(subtitleCollectionId)
        .operationTypeEqualTo('snapshot')
        .descriptionEqualTo('Initial state')
        .findFirst();
  }

  Future<List<Checkpoint>> getCheckpointsForSession(int sessionId) {
    return _isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByTimestampDesc()
        .findAll();
  }

  Future<Checkpoint?> getCurrentHeadCheckpoint(int sessionId) {
    return _isar.checkpoints
        .filter()
        .sessionIdEqualTo(sessionId)
        .isActiveEqualTo(true)
        .sortByTimestampDesc()
        .findFirst();
  }

  Future<int> putCheckpoint(Checkpoint checkpoint) async {
    late int checkpointId;
    await _isar.writeTxn(() async {
      checkpointId = await _isar.checkpoints.put(checkpoint);
    });
    return checkpointId;
  }

  Future<void> deleteCheckpointIds(Iterable<int> checkpointIds) async {
    final ids = checkpointIds.toList(growable: false);
    if (ids.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.checkpoints.deleteAll(ids);
    });
  }

  Future<int> insertAsHead({
    required int sessionId,
    required int? expectedHeadId,
    required Checkpoint checkpoint,
  }) async {
    late int checkpointId;

    await _isar.writeTxn(() async {
      final activeCheckpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .isActiveEqualTo(true)
          .sortByTimestampDesc()
          .findAll();

      final actualHeadId =
          CheckpointHeadReference.newestActive(activeCheckpoints)?.id;
      if (actualHeadId != expectedHeadId) {
        throw CheckpointConcurrentModificationException(
          expectedHeadId: expectedHeadId,
          actualHeadId: actualHeadId,
        );
      }

      CheckpointHeadReference.clearInMemory(activeCheckpoints);
      if (activeCheckpoints.isNotEmpty) {
        await _isar.checkpoints.putAll(activeCheckpoints);
      }

      checkpoint.isActive = true;
      checkpointId = await _isar.checkpoints.put(checkpoint);
    });

    return checkpointId;
  }

  Future<void> saveSubtitleCollection(SubtitleCollection collection) async {
    await _isar.writeTxn(() async {
      await _isar.subtitleCollections.put(collection);
    });
  }

  Future<void> restoreCollectionAndActivateOnly({
    required int sessionId,
    required Checkpoint targetCheckpoint,
    required SubtitleCollection collection,
    required int? expectedHeadId,
    required String expectedWorkingStateHash,
  }) async {
    await _isar.writeTxn(() async {
      final allCheckpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();

      final actualHead =
          CheckpointHeadReference.resolveForMutation(allCheckpoints);
      if (actualHead?.id != expectedHeadId) {
        throw CheckpointConcurrentModificationException(
          expectedHeadId: expectedHeadId,
          actualHeadId: actualHead?.id,
        );
      }

      final target = allCheckpoints
          .where((checkpoint) => checkpoint.id == targetCheckpoint.id)
          .firstOrNull;
      if (target == null ||
          target.subtitleCollectionId != collection.id ||
          target.sessionId != sessionId) {
        throw StateError('Checkpoint target is missing or belongs to another '
            'session/collection.');
      }

      // Fetch inside the write transaction. A stale caller-side collection
      // must never overwrite a concurrent edit or unrelated file metadata.
      final stored = await _isar.subtitleCollections.get(collection.id);
      if (stored == null) {
        throw StateError('Subtitle collection was deleted during checkout.');
      }
      if (CheckpointStateHasher.hashLines(stored.lines) !=
          expectedWorkingStateHash) {
        throw CheckpointIntegrityException(
          'Subtitle working tree changed during checkpoint checkout.',
        );
      }

      CheckpointHeadReference.moveInMemory(
        checkpoints: allCheckpoints,
        checkpointId: target.id,
      );
      await _isar.checkpoints.putAll(allCheckpoints);
      stored.lines = CheckpointStateReducer.copyLines(collection.lines);
      await _isar.subtitleCollections.put(stored);
    });
  }

  Future<void> deleteCheckpointsForSession(int sessionId) async {
    await _isar.writeTxn(() async {
      final checkpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();

      if (checkpoints.isNotEmpty) {
        await _isar.checkpoints.deleteAll(
          checkpoints.map((checkpoint) => checkpoint.id).toList(),
        );
      }
    });
  }
}
