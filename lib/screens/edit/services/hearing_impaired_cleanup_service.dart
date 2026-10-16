import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_transaction.dart';
import 'package:subtitle_studio/utils/subtitle_processor.dart';

class HearingImpairedCleanupResult {
  final int originalCount;
  final int removedCount;
  final int modifiedCount;
  final int remainingCount;

  const HearingImpairedCleanupResult({
    required this.originalCount,
    required this.removedCount,
    required this.modifiedCount,
    required this.remainingCount,
  });

  String get summaryMessage {
    final buffer = StringBuffer('Processed $originalCount lines. ');
    if (removedCount > 0) {
      buffer.write('$removedCount lines deleted. ');
    }
    if (modifiedCount > 0) {
      buffer.write('$modifiedCount lines modified. ');
    }
    buffer.write('$remainingCount lines remaining.');
    return buffer.toString();
  }
}

class HearingImpairedCleanupPlan {
  final List<SubtitleLine> cleanedLines;
  final List<SubtitleLineDelta> deltas;
  final HearingImpairedCleanupResult result;

  const HearingImpairedCleanupPlan({
    required this.cleanedLines,
    required this.deltas,
    required this.result,
  });
}

class HearingImpairedCleanupService {
  const HearingImpairedCleanupService._();

  static HearingImpairedCleanupPlan buildPlan(
    List<SubtitleLine> currentLines,
  ) {
    final source = List<SubtitleLine>.from(currentLines);
    final cleanedLines = removeHearingImpairedText(source);

    final cleanedByOriginalIndex = <int, SubtitleLine>{
      for (final line in cleanedLines) line.index: line,
    };

    final modifications = <SubtitleLineDelta>[];
    final deletions = <SubtitleLineDelta>[];
    var modifiedCount = 0;

    for (var i = 0; i < source.length; i++) {
      final before = source[i];
      final after = cleanedByOriginalIndex[before.index];

      if (after == null) {
        deletions.add(
          SubtitleLineDelta()
            ..changeType = 'delete'
            ..lineIndex = i
            ..beforeState = _copyLine(before)
            ..afterState = null,
        );
        continue;
      }

      if (!_samePersistedContent(before, after)) {
        modifiedCount++;
        modifications.add(
          SubtitleLineDelta()
            ..changeType = 'modify'
            ..lineIndex = i
            ..beforeState = _copyLine(before)
            ..afterState = _copyLine(after),
        );
      }
    }

    // Apply content modifications against the original indexes first. Delete
    // from the end so earlier removals cannot shift the indexes of later
    // delete deltas during strict history replay.
    deletions.sort((a, b) => b.lineIndex.compareTo(a.lineIndex));
    final deltas = <SubtitleLineDelta>[
      ...modifications,
      ...deletions,
    ];

    final result = HearingImpairedCleanupResult(
      originalCount: source.length,
      removedCount: source.length - cleanedLines.length,
      modifiedCount: modifiedCount,
      remainingCount: cleanedLines.length,
    );

    return HearingImpairedCleanupPlan(
      cleanedLines: cleanedLines,
      deltas: deltas,
      result: result,
    );
  }

  static Future<HearingImpairedCleanupResult> execute({
    required Isar isar,
    required int sessionId,
    required int subtitleCollectionId,
  }) async {
    final history = CheckpointHistoryTransaction(isar);
    late HearingImpairedCleanupResult cleanupResult;

    await history.commit(
      sessionId: sessionId,
      subtitleCollectionId: subtitleCollectionId,
      operationType: 'batch',
      description: 'Remove hearing impaired text',
      buildMutation: (currentLines) {
        final plan = buildPlan(currentLines);
        cleanupResult = plan.result;

        if (plan.deltas.isEmpty) {
          return CheckpointMutationPlan(
            nextLines: currentLines.map(_copyLine).toList(growable: true),
            deltas: const <SubtitleLineDelta>[],
          );
        }

        final normalized = <SubtitleLine>[
          for (var i = 0; i < plan.cleanedLines.length; i++)
            _copyLine(plan.cleanedLines[i])..index = i + 1,
        ];

        return CheckpointMutationPlan(
          nextLines: normalized,
          deltas: plan.deltas,
          forceSnapshot: true,
        );
      },
    );

    return cleanupResult;
  }

  static bool _samePersistedContent(
    SubtitleLine before,
    SubtitleLine after,
  ) {
    return before.startTime == after.startTime &&
        before.endTime == after.endTime &&
        before.original == after.original &&
        before.edited == after.edited &&
        before.marked == after.marked &&
        before.comment == after.comment &&
        before.resolved == after.resolved;
  }

  static SubtitleLine _copyLine(SubtitleLine line) {
    return SubtitleLine()
      ..index = line.index
      ..startTime = line.startTime
      ..endTime = line.endTime
      ..original = line.original
      ..edited = line.edited
      ..marked = line.marked
      ..comment = line.comment
      ..resolved = line.resolved;
  }
}
