import 'package:flutter/foundation.dart';
import 'package:subtitle_studio/database/database_instance.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
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
    final deltas = <SubtitleLineDelta>[];

    final cleanedByOriginalIndex = <int, SubtitleLine>{
      for (final line in cleanedLines) line.index: line,
    };

    int modifiedCount = 0;
    for (int i = 0; i < source.length; i++) {
      final before = source[i];
      final after = cleanedByOriginalIndex[before.index];

      if (after == null) {
        deltas.add(
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
        deltas.add(
          SubtitleLineDelta()
            ..changeType = 'modify'
            ..lineIndex = i
            ..beforeState = _copyLine(before)
            ..afterState = _copyLine(after),
        );
      }
    }

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
    required int sessionId,
    required int subtitleCollectionId,
    required List<SubtitleLine> currentLines,
  }) async {
    final plan = buildPlan(currentLines);

    if (plan.deltas.isNotEmpty) {
      try {
        await CheckpointRepository.fromGlobal().createCheckpoint(
          sessionId: sessionId,
          subtitleCollectionId: subtitleCollectionId,
          operationType: 'batch',
          description: 'Remove hearing impaired text',
          deltas: plan.deltas,
        );
      } catch (error) {
        debugPrint(
          'Could not create hearing-impaired cleanup checkpoint: $error',
        );
      }
    }

    await isar.writeTxn(() async {
      final collection =
          await isar.subtitleCollections.get(subtitleCollectionId);
      if (collection == null) {
        throw StateError(
          'Subtitle collection $subtitleCollectionId was not found.',
        );
      }

      collection.lines = [
        for (int i = 0; i < plan.cleanedLines.length; i++)
          _copyLine(plan.cleanedLines[i])..index = i + 1,
      ];

      await isar.subtitleCollections.put(collection);
    });

    return plan.result;
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
