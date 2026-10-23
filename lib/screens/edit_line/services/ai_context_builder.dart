import 'package:subtitle_studio/database/models/models.dart';

class EditLineAiContext {
  final List<String> previousLines;
  final List<String> nextLines;
  final List<String> allLines;
  final List<String> originalAllLines;
  final List<String> editedAllLines;
  final int currentIndex;

  const EditLineAiContext({
    required this.previousLines,
    required this.nextLines,
    required this.allLines,
    required this.originalAllLines,
    required this.editedAllLines,
    required this.currentIndex,
  });
}

class EditLineAiContextBuilder {
  const EditLineAiContextBuilder._();

  static EditLineAiContext build({
    required List<SubtitleLine> lines,
    required int currentIndex,
    required bool useEditedText,
    int contextRadius = 3,
  }) {
    if (lines.isEmpty) {
      return const EditLineAiContext(
        previousLines: [],
        nextLines: [],
        allLines: [],
        originalAllLines: [],
        editedAllLines: [],
        currentIndex: 0,
      );
    }

    final safeIndex = currentIndex.clamp(0, lines.length - 1).toInt();
    final radius = contextRadius < 0 ? 0 : contextRadius;

    String rendered(SubtitleLine line) {
      if (useEditedText && line.edited?.isNotEmpty == true) {
        return line.edited!;
      }
      return line.original;
    }

    String editedOrOriginal(SubtitleLine line) {
      return line.edited?.isNotEmpty == true
          ? line.edited!
          : line.original;
    }

    final previousStart =
        (safeIndex - radius).clamp(0, safeIndex).toInt();
    final nextEnd = (safeIndex + radius + 1)
        .clamp(safeIndex + 1, lines.length)
        .toInt();

    return EditLineAiContext(
      previousLines: [
        for (int i = previousStart; i < safeIndex; i++)
          rendered(lines[i]),
      ],
      nextLines: [
        for (int i = safeIndex + 1; i < nextEnd; i++)
          rendered(lines[i]),
      ],
      allLines: [for (final line in lines) rendered(line)],
      originalAllLines: [for (final line in lines) line.original],
      editedAllLines: [
        for (final line in lines) editedOrOriginal(line),
      ],
      currentIndex: safeIndex,
    );
  }
}
