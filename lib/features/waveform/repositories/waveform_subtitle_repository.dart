import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Persistence boundary for waveform-driven subtitle timing edits.
class WaveformSubtitleRepository {
  final Isar _isar;

  WaveformSubtitleRepository(this._isar);

  /// Replaces the requested subtitle lines by their stable 1-based cue index.
  ///
  /// Returns false if the collection is missing or if any requested cue cannot
  /// be matched, preventing a partial/false-success write.
  Future<bool> updateLines(
    int subtitleCollectionId,
    List<SubtitleLine> updatedLines,
  ) async {
    if (updatedLines.isEmpty) return true;

    try {
      return await _isar.writeTxn(() async {
        final collection =
            await _isar.subtitleCollections.get(subtitleCollectionId);
        if (collection == null) {
          await logWarning(
            'WaveformSubtitleRepository: collection not found: '
            '$subtitleCollectionId',
          );
          return false;
        }

        final replacements = <int, SubtitleLine>{
          for (final line in updatedLines) line.index: line,
        };
        final matchedIndexes = <int>{};

        for (int i = 0; i < collection.lines.length; i++) {
          final currentIndex = collection.lines[i].index;
          final replacement = replacements[currentIndex];
          if (replacement != null) {
            collection.lines[i] = replacement;
            matchedIndexes.add(currentIndex);
          }
        }

        if (matchedIndexes.length != replacements.length) {
          await logWarning(
            'WaveformSubtitleRepository: one or more subtitle lines were '
            'not found in collection $subtitleCollectionId',
          );
          return false;
        }

        await _isar.subtitleCollections.put(collection);
        return true;
      });
    } catch (error, stackTrace) {
      await logError(
        'WaveformSubtitleRepository: failed to update subtitle lines',
        context: 'updateLines',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
