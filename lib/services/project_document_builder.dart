import 'package:subtitle_studio/database/models/models.dart';

/// Builds the serializable payload stored in a .msone project file.
///
/// This class is pure: it has no database, platform, file-system, or UI
/// dependencies. That makes project-document compatibility independently
/// testable from persistence and file picking.
class ProjectDocumentBuilder {
  const ProjectDocumentBuilder._();

  static Map<String, dynamic> build({
    required Session session,
    required SubtitleCollection subtitleCollection,
    required List<Checkpoint> checkpoints,
    required String projectVersion,
    required String appVersion,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toIso8601String();

    return {
      'version': projectVersion,
      'createdAt': timestamp,
      'appVersion': appVersion,
      'session': {
        'fileName': session.fileName,
        'lastEditedIndex': session.lastEditedIndex,
        'editMode': session.editMode,
        'projectFilePath': session.projectFilePath,
      },
      'subtitleCollection': {
        'fileName': subtitleCollection.fileName,
        'filePath': subtitleCollection.filePath,
        'originalFileUri': subtitleCollection.originalFileUri,
        'encoding': subtitleCollection.encoding,
        'lines': subtitleCollection.lines.map(_serializeLine).toList(),
      },
      'checkpoints': checkpoints.map(_serializeCheckpoint).toList(),
      'metadata': {
        'totalLines': subtitleCollection.lines.length,
        'editedLines': subtitleCollection.lines
            .where((line) => line.edited != null && line.edited!.isNotEmpty)
            .length,
        'markedLines':
            subtitleCollection.lines.where((line) => line.marked).length,
        'lastSaved': timestamp,
      },
    };
  }

  static Map<String, dynamic> _serializeCheckpoint(Checkpoint checkpoint) {
    return {
      'sessionId': checkpoint.sessionId,
      'subtitleCollectionId': checkpoint.subtitleCollectionId,
      'timestamp': checkpoint.timestamp.toIso8601String(),
      'operationType': checkpoint.operationType,
      'description': checkpoint.description,
      'parentCheckpointId': checkpoint.parentCheckpointId,
      'isActive': checkpoint.isActive,
      'checkpointType': checkpoint.checkpointType,
      'metadata': checkpoint.metadata,
      'deltas': checkpoint.deltas.map(_serializeDelta).toList(),
      'snapshot': checkpoint.snapshot.map(_serializeLine).toList(),
    };
  }

  static Map<String, dynamic> _serializeDelta(SubtitleLineDelta delta) {
    return {
      'changeType': delta.changeType,
      'lineIndex': delta.lineIndex,
      'beforeState':
          delta.beforeState == null ? null : _serializeLine(delta.beforeState!),
      'afterState':
          delta.afterState == null ? null : _serializeLine(delta.afterState!),
    };
  }

  static Map<String, dynamic> _serializeLine(SubtitleLine line) {
    return {
      'index': line.index,
      'startTime': line.startTime,
      'endTime': line.endTime,
      'original': line.original,
      'edited': line.edited,
      'marked': line.marked,
      'comment': line.comment,
      'resolved': line.resolved,
    };
  }
}
