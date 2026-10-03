import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Low-level Isar persistence boundary for checkpoint history.
///
/// This store owns checkpoint/collection queries and atomic writes only.
/// Checkpoint policy, branching decisions, reconstruction, and user-facing
/// orchestration remain in CheckpointManager and the pure checkpoint helpers.
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

  Future<int> replaceActivePathAndInsert({
    required List<Checkpoint> existingCheckpoints,
    required Set<int> activePathIds,
    required Checkpoint checkpoint,
  }) async {
    late int checkpointId;

    await _isar.writeTxn(() async {
      for (final existing in existingCheckpoints) {
        existing.isActive = activePathIds.contains(existing.id);
      }

      if (existingCheckpoints.isNotEmpty) {
        await _isar.checkpoints.putAll(existingCheckpoints);
      }

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
  }) async {
    await _isar.writeTxn(() async {
      final allCheckpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(sessionId)
          .findAll();

      for (final checkpoint in allCheckpoints) {
        checkpoint.isActive = false;
      }
      targetCheckpoint.isActive = true;

      if (allCheckpoints.isNotEmpty) {
        await _isar.checkpoints.putAll(allCheckpoints);
      }
      await _isar.checkpoints.put(targetCheckpoint);
      await _isar.subtitleCollections.put(collection);
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
