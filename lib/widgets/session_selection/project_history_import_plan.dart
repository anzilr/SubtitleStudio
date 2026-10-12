import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_history_validator.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

/// Import failure is separate from subtitle recovery. The UI can explicitly
/// offer to import only the subtitle lines without the invalid history.
class ProjectHistoryImportException implements Exception {
  final String message;

  const ProjectHistoryImportException(this.message);

  @override
  String toString() => 'Project history cannot be imported: $message';
}

/// An in-memory, validated history graph. No Isar data is modified here.
/// Temporary IDs and ownership are remapped when the destination transaction
/// inserts the checkpoints.
class PreparedProjectHistory {
  final List<Checkpoint> checkpoints;

  const PreparedProjectHistory._(this.checkpoints);

  static PreparedProjectHistory build(
    List<ProjectCheckpointData> source, {
    required SubtitleLine Function(ProjectSubtitleLineData) toSubtitleLine,
  }) {
    if (source.isEmpty) {
      return const PreparedProjectHistory._(<Checkpoint>[]);
    }

    final checkpoints = <Checkpoint>[];
    final sourceIds = <int>{};
    int? originalSessionId;
    int? originalCollectionId;
    try {
      for (final entry in source) {
        // Projects may have legacy null identifiers, but non-null source
        // ownership must not jump between sessions or collections.
        final sourceSession = entry.sessionId;
        final sourceCollection = entry.subtitleCollectionId;
        if (sourceSession != null) {
          if (originalSessionId != null &&
              sourceSession != originalSessionId) {
            throw const ProjectHistoryImportException(
              'History contains checkpoints from multiple source sessions.',
            );
          }
          originalSessionId = sourceSession;
        }
        if (sourceCollection != null) {
          if (originalCollectionId != null &&
              sourceCollection != originalCollectionId) {
            throw const ProjectHistoryImportException(
              'History contains checkpoints from multiple subtitle collections.',
            );
          }
          originalCollectionId = sourceCollection;
        }
        final id = entry.id;
        if (id == null || id <= 0 || !sourceIds.add(id)) {
          throw ProjectHistoryImportException(
            'Checkpoint IDs must be positive, present and unique.',
          );
        }
        final timestamp = entry.timestamp;
        if (timestamp == null) {
          throw const ProjectHistoryImportException(
            'A checkpoint is missing its timestamp.',
          );
        }
        final checkpoint = Checkpoint(
          sessionId: 1,
          subtitleCollectionId: 1,
          timestamp: DateTime.parse(timestamp),
          operationType: entry.operationType,
          description: entry.description,
          parentCheckpointId: entry.parentCheckpointId,
          isActive: entry.isActive,
          checkpointType: entry.checkpointType,
          metadata: entry.metadata,
          deltas: entry.deltas.map((data) {
            return SubtitleLineDelta()
              ..changeType = data.changeType
              ..lineIndex = data.lineIndex
              ..beforeState = data.beforeState == null
                  ? null
                  : toSubtitleLine(data.beforeState!)
              ..afterState = data.afterState == null
                  ? null
                  : toSubtitleLine(data.afterState!);
          }).toList(growable: false),
          snapshot: entry.snapshot.map(toSubtitleLine).toList(growable: false),
        )..id = id;
        final decoded = CheckpointHistoryMetadata.decode(entry.metadata);
        final declaredVersion = decoded['_historyVersion'];
        if (declaredVersion != null &&
            declaredVersion != 1 &&
            !CheckpointHistoryMetadata.isPostOperation(checkpoint)) {
          throw ProjectHistoryImportException(
            'Unsupported checkpoint history version or state semantics '
            'at checkpoint $id.',
          );
        }
        checkpoints.add(checkpoint);
      }

      final hasV2 = checkpoints.any(CheckpointHistoryMetadata.isPostOperation);
      if (hasV2) {
        final active = CheckpointHeadReference.activeCheckpoints(checkpoints);
        if (active.length != 1) {
          throw ProjectHistoryImportException(
            'Version 2 history requires exactly one HEAD, found '
            '${active.length}.',
          );
        }
        for (final checkpoint in checkpoints) {
          if (CheckpointHistoryMetadata.isPostOperation(checkpoint) &&
              CheckpointHistoryMetadata.stateHash(checkpoint) == null) {
            throw ProjectHistoryImportException(
              'Version 2 checkpoint ${checkpoint.id} has no state hash.',
            );
          }
        }
      } else {
        // Legacy history may have an active ancestor path or no flags.
        // Preserve its selected position as one HEAD for the new database.
        final active = CheckpointHeadReference.activeCheckpoints(checkpoints);
        final ordered = checkpoints.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        CheckpointHeadReference.moveInMemory(
          checkpoints: checkpoints,
          checkpointId: (active.isEmpty ? ordered.first : active.first).id,
        );
      }

      final health = CheckpointHistoryValidator.validate(
        sessionId: 1,
        checkpoints: checkpoints,
      );
      if (!health.isHealthy) {
        throw ProjectHistoryImportException(health.issues.join('; '));
      }
      return PreparedProjectHistory._(checkpoints);
    } on ProjectHistoryImportException {
      rethrow;
    } on FormatException catch (error) {
      throw ProjectHistoryImportException(error.message);
    } on Exception catch (error) {
      throw ProjectHistoryImportException(error.toString());
    }
  }
}
