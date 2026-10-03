import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

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
    required String projectVersion,
    required String appVersion,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toIso8601String();

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
