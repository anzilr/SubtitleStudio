import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';

/// Protects V2 history from compatibility-only full-collection replacements.
///
/// Must be called from the caller's write transaction: a separate preflight
/// would allow a new history commit to arrive between the check and write.
/// Legacy V1 projects remain readable and can still follow their old paths.
class LegacyCollectionWriteGuard {
  const LegacyCollectionWriteGuard._();

  static Future<bool> canReplaceEntireCollection(
    Isar isar,
    int collectionId,
  ) async {
    final history = await isar.checkpoints
        .filter()
        .subtitleCollectionIdEqualTo(collectionId)
        .findAll();
    return !history.any(CheckpointHistoryMetadata.isPostOperation);
  }
}
