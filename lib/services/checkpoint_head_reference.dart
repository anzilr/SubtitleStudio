import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Compatibility abstraction for the current HEAD reference.
///
/// Today HEAD is persisted through Checkpoint.isActive. All semantic decisions
/// about that representation live here so a future HistoryRef collection can
/// replace it without changing managers, validators, or transaction logic.
class CheckpointHeadReference {
  const CheckpointHeadReference._();

  static List<Checkpoint> activeCheckpoints(
    Iterable<Checkpoint> checkpoints,
  ) {
    final active = checkpoints
        .where((checkpoint) => checkpoint.isActive)
        .toList(growable: false)
      ..sort(_newestFirst);
    return active;
  }

  static Checkpoint? newestActive(
    Iterable<Checkpoint> checkpoints,
  ) {
    final active = activeCheckpoints(checkpoints);
    return active.isEmpty ? null : active.first;
  }

  /// Resolves HEAD while preserving compatibility with legacy active paths.
  ///
  /// Legacy-only histories may contain multiple active ancestors. Once any v2
  /// commit exists, HEAD must be represented by exactly one active checkpoint.
  /// That checkpoint may itself be legacy when the user checks out old history.
  static Checkpoint? resolveForMutation(
    List<Checkpoint> checkpoints,
  ) {
    final active = activeCheckpoints(checkpoints);
    if (active.isEmpty) return null;

    final containsV2 =
        checkpoints.any(CheckpointHistoryMetadata.isPostOperation);
    if (containsV2 && active.length != 1) {
      throw CheckpointIntegrityException(
        'History with v2 commits must have exactly one HEAD; '
        'found \${active.length}.',
      );
    }

    return active.first;
  }

  static void moveInMemory({
    required Iterable<Checkpoint> checkpoints,
    required int checkpointId,
  }) {
    var found = false;
    for (final checkpoint in checkpoints) {
      final isHead = checkpoint.id == checkpointId;
      checkpoint.isActive = isHead;
      found = found || isHead;
    }

    if (!found) {
      throw StateError(
        'Cannot move HEAD to missing checkpoint $checkpointId.',
      );
    }
  }

  static void clearInMemory(Iterable<Checkpoint> checkpoints) {
    for (final checkpoint in checkpoints) {
      checkpoint.isActive = false;
    }
  }

  static int _newestFirst(Checkpoint a, Checkpoint b) {
    final timestamp = b.timestamp.compareTo(a.timestamp);
    if (timestamp != 0) return timestamp;
    return b.id.compareTo(a.id);
  }
}
