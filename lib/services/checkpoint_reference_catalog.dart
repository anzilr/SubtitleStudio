import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';

/// Typed, read-only Git-inspired references derived from stored checkpoint
/// history. HEAD is backed by the legacy isActive flag until the planned
/// Isar HistoryRef schema migration. Branch tips and manual bookmarks here
/// are DISCOVERED views, not yet user-created persistent named references.
enum CheckpointReferenceKind { head, branchTip, manualBookmark }

class CheckpointReference {
  final String name;
  final int checkpointId;
  final CheckpointReferenceKind kind;

  const CheckpointReference({
    required this.name,
    required this.checkpointId,
    required this.kind,
  });
}

/// Provides a stable logical reference vocabulary to new history UIs and
/// retention logic without requiring an unsafe manual change to models.g.dart.
class CheckpointReferenceCatalog {
  const CheckpointReferenceCatalog._();

  static List<CheckpointReference> fromHistory(List<Checkpoint> checkpoints) {
    if (checkpoints.isEmpty) return const <CheckpointReference>[];
    final sessionId = checkpoints.first.sessionId;
    final collectionId = checkpoints.first.subtitleCollectionId;
    final byId = <int, Checkpoint>{};
    for (final c in checkpoints) {
      if (c.id <= 0 ||
          c.sessionId != sessionId ||
          c.subtitleCollectionId != collectionId ||
          byId.containsKey(c.id)) {
        throw StateError('Cannot derive refs from mixed or invalid history.');
      }
      byId[c.id] = c;
    }
    for (final c in checkpoints) {
      final parentId = c.parentCheckpointId;
      if (parentId != null && !byId.containsKey(parentId)) {
        throw StateError('Cannot derive refs from history with missing parents.');
      }
    }

    final head = CheckpointHeadReference.resolveForMutation(checkpoints);
    final references = <CheckpointReference>[
      if (head != null)
        CheckpointReference(
          name: 'HEAD',
          checkpointId: head.id,
          kind: CheckpointReferenceKind.head,
        ),
    ];
    final parentIds = <int>{
      for (final c in checkpoints)
        if (c.parentCheckpointId != null) c.parentCheckpointId!,
    };
    final branchTips = checkpoints
        .where((c) => !parentIds.contains(c.id) && c.id != head?.id)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final tip in branchTips) {
      references.add(CheckpointReference(
        name: 'refs/heads/alternate-${tip.id}',
        checkpointId: tip.id,
        kind: CheckpointReferenceKind.branchTip,
      ));
    }
    final manualCheckpoints = checkpoints
        .where((c) => c.operationType == 'manual')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final manual in manualCheckpoints) {
      references.add(CheckpointReference(
        name: 'refs/bookmarks/manual-${manual.id}',
        checkpointId: manual.id,
        kind: CheckpointReferenceKind.manualBookmark,
      ));
    }
    return List<CheckpointReference>.unmodifiable(references);
  }
}
