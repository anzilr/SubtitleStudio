import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_state.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// Pure projection of a selected cue into the Riverpod state snapshot.
///
/// A completed Isar/checkpoint transaction owns cue order. Neither the screen
/// nor the controller should patch a single cached row at the old index or
/// retain a pre-save `subtitleLine` reference.
class EditLineSelectionProjection {
  const EditLineSelectionProjection._();

  static EditLineState apply({
    required EditLineState current,
    required SubtitleCollection collection,
    required SubtitleLine selectedLine,
    required List<SubtitleLine> orderedLines,
    String? displayedEditedText,
  }) {
    // Copy the collection and every embedded line, including comments,
    // checkpoint-relevant marks and intentionally blank edited strings.
    // Never mutate the state snapshot that listeners already received.
    final copiedCollection = SubtitleCollection(
      fileName: collection.fileName,
      filePath: collection.filePath,
      originalFileUri: collection.originalFileUri,
      encoding: collection.encoding,
      macOsSrtBookmark: collection.macOsSrtBookmark,
      lines: CheckpointStateReducer.copyLines(orderedLines),
    )..id = collection.id;

    // Existing cue selection follows its post-sort index. A new unsaved cue
    // can sit just beyond the persisted collection's final row.
    final index = selectedLine.index - 1;
    final selected = index >= 0 &&
            index < copiedCollection.lines.length
        ? copiedCollection.lines[index]
        : CheckpointStateReducer.copyLine(selectedLine);

    return current.copyWith(
      subtitleLine: selected,
      subtitleCollection: copiedCollection,
      originalText: selected.original,
      editedText: displayedEditedText ??
          (selected.edited?.replaceAll('<br>', '\n') ?? ''),
      startTime: selected.startTime,
      endTime: selected.endTime,
      hasUnsavedChanges: false,
      isLoading: false,
      clearStartTimeError: true,
      clearEndTimeError: true,
      clearTimeOrderError: true,
      clearErrorMessage: true,
    );
  }
}
