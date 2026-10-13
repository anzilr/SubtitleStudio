import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// A proposed durable history ref, created without modifying Isar.
///
/// Until HistoryRef has its own generated Isar schema, these values describe
/// the migration and import remapping contract only. They are not persisted.
class PlannedHistoryReference {
  final String name;
  final CheckpointReferenceKind kind;
  final int checkpointId;

  const PlannedHistoryReference({
    required this.name,
    required this.kind,
    required this.checkpointId,
  });
}

/// Deterministic, read-only draft of a future HistoryRef migration.
///
/// All checkpoint IDs here are local to one history. A project import must
/// remap them after creating new Isar IDs, before persisting actual refs.
/// Preparing this plan never changes legacy isActive flags or user data.
class CheckpointReferenceMigrationPlan {
  final int? sessionId;
  final int? subtitleCollectionId;
  final int? headCheckpointId;
  final bool requiresLegacyHeadNormalization;
  final List<PlannedHistoryReference> references;
  final Set<int> sourceCheckpointIds;

  CheckpointReferenceMigrationPlan._({
    required this.sessionId,
    required this.subtitleCollectionId,
    required this.headCheckpointId,
    required this.requiresLegacyHeadNormalization,
    required List<PlannedHistoryReference> references,
    required Set<int> sourceCheckpointIds,
  }) : references = List<PlannedHistoryReference>.unmodifiable(references),
       sourceCheckpointIds = Set<int>.unmodifiable(sourceCheckpointIds);

  static CheckpointReferenceMigrationPlan prepare(
    List<Checkpoint> checkpoints,
  ) {
    if (checkpoints.isEmpty) {
      return CheckpointReferenceMigrationPlan._(
        sessionId: null,
        subtitleCollectionId: null,
        headCheckpointId: null,
        requiresLegacyHeadNormalization: false,
        references: const [],
        sourceCheckpointIds: const {},
      );
    }

    final session = checkpoints.first.sessionId;
    final collection = checkpoints.first.subtitleCollectionId;
    final byId = <int, Checkpoint>{};
    for (final commit in checkpoints) {
      if (commit.id <= 0 ||
          commit.sessionId != session ||
          commit.subtitleCollectionId != collection ||
          byId.containsKey(commit.id)) {
        throw const CheckpointIntegrityException(
          'History reference migration requires unique positive IDs '
          'and one session/collection.',
        );
      }
      byId[commit.id] = commit;
    }
    // Validate the parent graph without recursion (legacy archives may be
    // long), and reject broken links and cycles before proposing any refs.
    final visited = <int>{};
    for (final commit in checkpoints) {
      final path = <int>{};
      Checkpoint? current = commit;
      while (current != null && !visited.contains(current.id)) {
        if (!path.add(current.id)) {
          throw const CheckpointIntegrityException(
            'Cannot create history refs from a cyclic parent graph.',
          );
        }
        final parentId = current.parentCheckpointId;
        if (parentId != null && !byId.containsKey(parentId)) {
          throw const CheckpointIntegrityException(
            'Cannot create history refs with a missing parent checkpoint.',
          );
        }
        current = parentId == null ? null : byId[parentId];
      }
      visited.addAll(path);
    }

    final isV2 = checkpoints.any(CheckpointHistoryMetadata.isPostOperation);
    final head = isV2
        ? CheckpointHeadReference.resolveForMutation(checkpoints)
        : (CheckpointHeadReference.newestActive(checkpoints) ??
              (checkpoints.toList()
                  ..sort((a, b) {
                    final byTime = b.timestamp.compareTo(a.timestamp);
                    return byTime != 0 ? byTime : b.id.compareTo(a.id);
                  })).first);
    if (head == null) {
      throw const CheckpointIntegrityException(
        'A V2 history must have an unambiguous active HEAD.',
      );
    }

    final refList = <PlannedHistoryReference>[
      PlannedHistoryReference(
        name: 'HEAD',
        checkpointId: head.id,
        kind: CheckpointReferenceKind.head,
      ),
      PlannedHistoryReference(
        name: 'refs/heads/main',
        checkpointId: head.id,
        kind: CheckpointReferenceKind.branchTip,
      ),
    ];

    final parentIds = <int>{
      for (final commit in checkpoints)
        if (commit.parentCheckpointId != null) commit.parentCheckpointId!,
    };
    final alternateTips = checkpoints
        .where((c) => !parentIds.contains(c.id) && c.id != head.id)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final tip in alternateTips) {
      refList.add(PlannedHistoryReference(
        name: 'refs/heads/alternate-${tip.id}',
        checkpointId: tip.id,
        kind: CheckpointReferenceKind.branchTip,
      ));
    }
    final manual = checkpoints.where((c) => c.operationType == 'manual').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final bookmark in manual) {
      refList.add(PlannedHistoryReference(
        name: 'refs/bookmarks/manual-${bookmark.id}',
        checkpointId: bookmark.id,
        kind: CheckpointReferenceKind.manualBookmark,
      ));
    }

    final names = <String>{};
    for (final ref in refList) {
      if (!names.add(ref.name) || !byId.containsKey(ref.checkpointId)) {
        throw const CheckpointIntegrityException(
          'History reference names and targets must be unique and valid.',
        );
      }
    }
    final active = CheckpointHeadReference.activeCheckpoints(checkpoints);
    return CheckpointReferenceMigrationPlan._(
      sessionId: session,
      subtitleCollectionId: collection,
      headCheckpointId: head.id,
      requiresLegacyHeadNormalization:
          !isV2 && (active.length != 1 || active.single.id != head.id),
      references: refList,
      sourceCheckpointIds: byId.keys.toSet(),
    );
  }

  /// Rebase a validated plan after project import has allocated new Isar IDs.
  ///
  /// The ref names remain stable across import, even as their target IDs are
  /// remapped. Missing mappings or two old IDs mapping to one destination ID
  /// fail before any transaction can persist the refs.
  CheckpointReferenceMigrationPlan remap({
    required int destinationSessionId,
    required int destinationCollectionId,
    required Map<int, int> idMap,
  }) {
    if (destinationSessionId <= 0 || destinationCollectionId <= 0 ||
        idMap.length != sourceCheckpointIds.length ||
        !idMap.keys.toSet().containsAll(sourceCheckpointIds) ||
        idMap.values.any((id) => id <= 0) ||
        idMap.values.toSet().length != idMap.length) {
      throw const CheckpointIntegrityException(
        'History refs require a complete injective checkpoint ID remap.',
      );
    }

    return CheckpointReferenceMigrationPlan._(
      sessionId: destinationSessionId,
      subtitleCollectionId: destinationCollectionId,
      headCheckpointId: headCheckpointId == null ? null : idMap[headCheckpointId],
      requiresLegacyHeadNormalization: requiresLegacyHeadNormalization,
      references: [
        for (final ref in references)
          PlannedHistoryReference(
            name: ref.name,
            kind: ref.kind,
            checkpointId: idMap[ref.checkpointId]!,
          ),
      ],
      sourceCheckpointIds: idMap.values.toSet(),
    );
  }
}
