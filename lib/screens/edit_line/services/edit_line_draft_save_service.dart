import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/models/edit_line_committed_cue.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Failed saves keep both the active cue and the UI's collection unchanged.
class EditLineDraftSaveResult {
  final bool saved;
  final SubtitleLine? savedLine;
  final List<SubtitleLine>? persistedLines;

  const EditLineDraftSaveResult._(
    this.saved,
    this.savedLine,
    this.persistedLines,
  );

  const EditLineDraftSaveResult.failed() : this._(false, null, null);

  EditLineDraftSaveResult.success(EditLineCommittedCue committed)
      : this._(true, committed.selectedLine, committed.lines);
}

/// Single transaction-based path for manual Save and navigation autosave.
///
/// Existing and inserted cues both return the committed row order and actual
/// selected index. No UI cache is changed when persistence rejects the draft.
class EditLineDraftSaveService {
  final Future<EditLineCommittedCue?> Function(
    SubtitleLine, {SubtitleLine? beforeLine}
  ) saveExisting;
  final Future<EditLineCommittedCue?> Function(SubtitleLine, int) insertNew;
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

    final committed = insertLine
        ? await insertNew(updated, insertIndex)
        : await saveExisting(updated, beforeLine: before);
    if (committed == null) {
      return const EditLineDraftSaveResult.failed();
    }

    // Use the post-sort index, not the index before the transaction.
    try {
      await updateLastEditedIndex(committed.selectedLine.index);
    } catch (error, stackTrace) {
      onIndexUpdateError?.call(error, stackTrace);
    }
    return EditLineDraftSaveResult.success(committed);
  }
}
