import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_reconstructor.dart';

class CheckpointHistoryHealth {
  final List<String> issues;

  const CheckpointHistoryHealth(this.issues);

  bool get isHealthy => issues.isEmpty;
}

/// Explicit graph/integrity diagnostics for one session history.
///
/// This is intentionally stricter for v2 Git-style history than for legacy
/// pre-operation checkpoints. Legacy active-path flags remain tolerated until
/// migration is complete, while any v2 history must have exactly one HEAD.
class CheckpointHistoryValidator {
  const CheckpointHistoryValidator._();

  static CheckpointHistoryHealth validate({
    required int sessionId,
    required List<Checkpoint> checkpoints,
  }) {
    final issues = <String>[];
    if (checkpoints.isEmpty) {
      return const CheckpointHistoryHealth(<String>[]);
    }

    final byId = <int, Checkpoint>{};
    int? collectionId;

    for (final checkpoint in checkpoints) {
      if (checkpoint.id <= 0) {
        issues.add('Checkpoint has an invalid persistent ID \${checkpoint.id}.');
        continue;
      }
      if (byId.containsKey(checkpoint.id)) {
        issues.add('Duplicate checkpoint ID \${checkpoint.id}.');
      }
      byId[checkpoint.id] = checkpoint;

      if (checkpoint.sessionId != sessionId) {
        issues.add(
          'Checkpoint \${checkpoint.id} belongs to session '
          '\${checkpoint.sessionId}, expected $sessionId.',
        );
      }

      collectionId ??= checkpoint.subtitleCollectionId;
      if (checkpoint.subtitleCollectionId != collectionId) {
        issues.add(
          'Checkpoint \${checkpoint.id} references subtitle collection '
          '\${checkpoint.subtitleCollectionId}, expected $collectionId.',
        );
      }
    }

    for (final checkpoint in checkpoints) {
      final parentId = checkpoint.parentCheckpointId;
      if (parentId == null) continue;
      if (parentId == checkpoint.id) {
        issues.add('Checkpoint \${checkpoint.id} references itself as parent.');
      } else if (!byId.containsKey(parentId)) {
        issues.add(
          'Checkpoint \${checkpoint.id} references missing parent $parentId.',
        );
      }
    }

    for (final checkpoint in checkpoints) {
      final visited = <int>{};
      int? currentId = checkpoint.id;
      while (currentId != null) {
        if (!visited.add(currentId)) {
          issues.add(
            'Checkpoint history contains a parent cycle involving $currentId.',
          );
          break;
        }
        currentId = byId[currentId]?.parentCheckpointId;
      }
    }

    final v2 = checkpoints
        .where(CheckpointHistoryMetadata.isPostOperation)
        .toList(growable: false);
    if (v2.isNotEmpty) {
      final heads = checkpoints
          .where((checkpoint) => checkpoint.isActive)
          .toList(growable: false);
      if (heads.length != 1) {
        issues.add(
          'V2 history must have exactly one HEAD, found \${heads.length}.',
        );
      } else if (!CheckpointHistoryMetadata.isPostOperation(heads.single)) {
        issues.add(
          'V2 history HEAD \${heads.single.id} does not use v2 semantics.',
        );
      }

      for (final checkpoint in v2) {
        try {
          CheckpointReconstructor.reconstructPostOperation(
            checkpoints: checkpoints,
            targetCheckpointId: checkpoint.id,
          );
        } catch (error) {
          issues.add(
            'Checkpoint \${checkpoint.id} failed reconstruction: $error',
          );
        }
      }
    }

    return CheckpointHistoryHealth(
      List<String>.unmodifiable(issues),
    );
  }
}
