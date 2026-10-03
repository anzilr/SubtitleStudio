import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_import.dart';

class ProjectCommentRepository {
  final Isar _isar;

  const ProjectCommentRepository(this._isar);

  Future<int> importComments({
    required int subtitleCollectionId,
    required ProjectCommentImportPlan plan,
  }) async {
    final collection = await _isar.subtitleCollections.get(
      subtitleCollectionId,
    );
    if (collection == null) {
      throw StateError(
        'Subtitle collection not found: $subtitleCollectionId',
      );
    }

    final byIndex = {
      for (final entry in plan.entries) entry.index: entry,
    };

    var importedCount = 0;
    await _isar.writeTxn(() async {
      for (final line in collection.lines) {
        final imported = byIndex[line.index];
        if (imported == null) continue;

        line.comment = imported.comment;
        line.marked = imported.marked;
        line.resolved = imported.resolved;
        importedCount++;
      }

      await _isar.subtitleCollections.put(collection);
    });

    return importedCount;
  }
}
