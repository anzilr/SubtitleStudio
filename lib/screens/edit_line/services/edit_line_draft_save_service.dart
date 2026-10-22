import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Detached result of a manual Edit Line save or navigation autosave.
/// Failed writes leave the UI's original line object untouched.
class EditLineDraftSaveResult {
  final bool saved;
  final SubtitleLine? savedLine;

  const EditLineDraftSaveResult._(this.saved, this.savedLine);

  const EditLineDraftSaveResult.failed() : this._(false, null);

  EditLineDraftSaveResult.success(SubtitleLine line) : this._(true, line);
}

/// Shared commit path for Edit Line's manual Save and navigation autosave.
///
/// Screen validation and messages remain in the UI; this service prepares
/// detached checkpoint before/after lines, calls the existing transactional
/// repository, and only reports success when it accepted the mutation.
class EditLineDraftSaveService {
  final Future<bool> Function(SubtitleLine, {SubtitleLine? beforeLine})
      saveExisting;
  final Future<bool> Function(SubtitleLine, int) insertNew;
  final Future<void> Function(int) updateLastEditedIndex;
  final void Function(Object error, StackTrace stackTrace)? onIndexUpdateError;

  const EditLineDraftSaveService({
    required this.saveExisting,
    required this.insertNew,
    required this.updateLastEditedIndex,
    this.onIndexUpdateError,
  });

  Future<EditLineDraftSaveResult> save({
    required SubtitleLine currentLine,
    required String originalText,
    required String editedText,
    required String startTime,
    required String endTime,
    required String initialOriginalText,
    required String initialStartTime,
    required String initialEndTime,
    required bool isEditMode,
    required bool insertLine,
    required int insertIndex,
  }) async {
    final before = CheckpointStateReducer.copyLine(currentLine)
      ..original = initialOriginalText
      ..startTime = initialStartTime
      ..endTime = initialEndTime;

    final updated = CheckpointStateReducer.copyLine(currentLine)
      ..edited = editedText.replaceAll('\n', '<br>')
      ..startTime = startTime
      ..endTime = endTime;
    if (!isEditMode) {
      updated.original = originalText;
    }

    final accepted = insertLine
        ? await insertNew(updated, insertIndex)
        : await saveExisting(updated, beforeLine: before);
    if (!accepted) {
      return const EditLineDraftSaveResult.failed();
    }

    // Editing the session's last-selected index is bookkeeping, not part of
    // the successful checkpoint transaction. Do not misreport a saved line
    // as failed if this non-critical follow-up fails.
    try {
      await updateLastEditedIndex(updated.index);
    } catch (error, stackTrace) {
      onIndexUpdateError?.call(error, stackTrace);
    }
    return EditLineDraftSaveResult.success(updated);
  }
}
