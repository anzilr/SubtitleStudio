import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';

/// Builds the typed document stored in a .msone project file.
///
/// This class is pure: it has no database, platform, file-system, or UI
/// dependencies. JSON maps are produced only by the project codec.
class ProjectDocumentBuilder {
  const ProjectDocumentBuilder._();

  static ProjectDocument build({
    required Session session,
    required SubtitleCollection subtitleCollection,
    required List<Checkpoint> checkpoints,
    List<HistoryRef>? persistentReferences,
    required String projectVersion,
    required String appVersion,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    // Export a versioned view of the current logical refs. These names are
    // derived from the checkpoint graph until durable Isar refs are available.
    // Invalid graphs fail before a project file is written.
    final historyPlan = CheckpointReferenceMigrationPlan.prepare(checkpoints);
    final liveRefs = persistentReferences;
    // A stale export must never write refs targeting a different graph.
    if (liveRefs != null && liveRefs.isNotEmpty) {
      final ids = {for (final cp in checkpoints) cp.id: cp};
      final names = <String>{};
      for (final ref in liveRefs) {
        final cp = ids[ref.targetCheckpointId];
        if (!names.add(ref.name) || cp == null ||
            ref.sessionId != session.id ||
            cp.sessionId != ref.sessionId ||
            cp.subtitleCollectionId != ref.subtitleCollectionId) {
          throw StateError('Persistent refs do not match the exported history.');
        }
      }
      if (liveRefs.where((ref) => ref.name == 'HEAD').length != 1 ||
          liveRefs.firstWhere((ref) => ref.name == 'HEAD')
              .targetCheckpointId != historyPlan.headCheckpointId) {
        throw StateError('Export HEAD does not match the persisted checkpoint graph.');
      }
    }

    return ProjectDocument.create(
      version: projectVersion,
      createdAt: timestamp,
      appVersion: appVersion,
      session: ProjectSessionData.create(
        fileName: session.fileName,
        lastEditedIndex: session.lastEditedIndex,
        editMode: session.editMode,
        projectFilePath: session.projectFilePath,
      ),
      subtitleCollection: ProjectSubtitleCollectionData.create(
        fileName: subtitleCollection.fileName,
        filePath: subtitleCollection.filePath,
        originalFileUri: subtitleCollection.originalFileUri,
        encoding: subtitleCollection.encoding,
        lines: subtitleCollection.lines
            .map(_serializeLine)
            .toList(growable: false),
      ),
      checkpoints: checkpoints
          .map(_serializeCheckpoint)
          .toList(growable: false),
      historyReferences: historyPlan.references.isEmpty
          ? null
          : ProjectHistoryReferencesData.create(entries: [
              if (liveRefs != null && liveRefs.isNotEmpty)
                for (final ref in liveRefs)
                  ProjectHistoryReferenceData(
                    name: ref.name,
                    kind: ref.kind,
                    targetCheckpointId: ref.targetCheckpointId,
                    symbolicBranchName: ref.symbolicBranchName,
                    attachmentSpecified: ref.name == 'HEAD',
                  )
              else
                for (final ref in historyPlan.references)
                  ProjectHistoryReferenceData(
                    name: ref.name,
                    kind: switch (ref.kind) {
                      CheckpointReferenceKind.head => 'head',
                      CheckpointReferenceKind.branchTip => 'branch',
                      CheckpointReferenceKind.manualBookmark => 'bookmark',
                    },
                    targetCheckpointId: ref.checkpointId,
                    symbolicBranchName:
                        ref.name == 'HEAD' ? 'refs/heads/main' : null,
                    attachmentSpecified: ref.name == 'HEAD',
                  ),
            ]),
      metadata: ProjectMetadataData.create(
        totalLines: subtitleCollection.lines.length,
        editedLines: subtitleCollection.lines
            .where((line) => line.edited != null && line.edited!.isNotEmpty)
            .length,
        markedLines:
            subtitleCollection.lines.where((line) => line.marked).length,
        lastSaved: timestamp,
      ),
    );
  }

  static ProjectCheckpointData _serializeCheckpoint(
    Checkpoint checkpoint,
  ) {
    return ProjectCheckpointData.create(
      id: checkpoint.id,
      sessionId: checkpoint.sessionId,
      subtitleCollectionId: checkpoint.subtitleCollectionId,
      timestamp: checkpoint.timestamp.toIso8601String(),
      operationType: checkpoint.operationType,
      description: checkpoint.description,
      parentCheckpointId: checkpoint.parentCheckpointId,
      isActive: checkpoint.isActive,
      checkpointType: checkpoint.checkpointType,
      metadata: checkpoint.metadata,
      deltas: checkpoint.deltas
          .map(_serializeDelta)
          .toList(growable: false),
      snapshot: checkpoint.snapshot
          .map(_serializeLine)
          .toList(growable: false),
    );
  }

  static ProjectDeltaData _serializeDelta(SubtitleLineDelta delta) {
    return ProjectDeltaData.create(
      changeType: delta.changeType,
      lineIndex: delta.lineIndex,
      beforeState:
          delta.beforeState == null ? null : _serializeLine(delta.beforeState!),
      afterState:
          delta.afterState == null ? null : _serializeLine(delta.afterState!),
    );
  }

  static ProjectSubtitleLineData _serializeLine(SubtitleLine line) {
    return ProjectSubtitleLineData.create(
      index: line.index,
      startTime: line.startTime,
      endTime: line.endTime,
      original: line.original,
      edited: line.edited,
      marked: line.marked,
      comment: line.comment,
      resolved: line.resolved,
    );
  }
}
