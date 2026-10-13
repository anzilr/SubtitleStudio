import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';

/// Validates optional .msone reference data before any project import writes.
///
/// Checkpoint 68 can round-trip only *derived* refs: HEAD, main branch,
/// alternate tips and manual checkpoint bookmarks. User-named persistent refs
/// need the forthcoming generated Isar schema and must never be silently lost.
class ProjectHistoryReferenceImportPlan {
  const ProjectHistoryReferenceImportPlan._();

  static CheckpointReferenceMigrationPlan? prepare({
    required ProjectHistoryReferencesData? data,
    required PreparedProjectHistory? history,
  }) {
    if (data == null) return null;
    if (history == null) {
      throw const ProjectHistoryImportException(
        'History refs cannot be imported without checkpoint history.',
      );
    }
    try {
      final plan = CheckpointReferenceMigrationPlan.prepare(history.checkpoints);
      final expected = <String, (String, int)>{
        for (final ref in plan.references)
          ref.name: (
            switch (ref.kind) {
              CheckpointReferenceKind.head => 'head',
              CheckpointReferenceKind.branchTip => 'branch',
              CheckpointReferenceKind.manualBookmark => 'bookmark',
            },
            ref.checkpointId,
          ),
      };
      if (data.entries.length != expected.length) {
        throw const ProjectHistoryImportException(
          'This project has history refs that cannot yet be safely '
          'persisted. Import subtitles only or use a version supporting '
          'named references.',
        );
      }
      for (final ref in data.entries) {
        final target = expected[ref.name];
        if (target == null ||
            target.$1 != ref.kind ||
            target.$2 != ref.targetCheckpointId) {
          throw ProjectHistoryImportException(
            'Invalid or unsupported history ref: ${ref.name}. '
            'No project changes have been made.',
          );
        }
      }
      return plan;
    } on CheckpointIntegrityException catch (error) {
      throw ProjectHistoryImportException(error.message);
    }
  }
}
