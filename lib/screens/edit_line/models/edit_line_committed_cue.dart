import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

/// The actual cue position and ordered rows committed by one Isar transaction.
///
/// It cannot be reconstructed reliably by comparing text or timestamps:
/// distinct cues may have identical text and timecodes.
class EditLineCommittedCue {
  final SubtitleLine selectedLine;
  final List<SubtitleLine> lines;

  EditLineCommittedCue({
    required SubtitleLine selectedLine,
    required List<SubtitleLine> lines,
  })  : selectedLine = CheckpointStateReducer.copyLine(selectedLine),
        lines = List<SubtitleLine>.unmodifiable(
          CheckpointStateReducer.copyLines(lines),
        );
}
