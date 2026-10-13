import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';

/// Validates all archived refs against the complete graph before an import
/// transaction. A valid custom name must never be silently regenerated.
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
      final ids = plan.sourceCheckpointIds;
      if (data.entries.isEmpty || ids.isEmpty) {
        throw const ProjectHistoryImportException(
          'A referenced history must contain checkpoints and HEAD.',
        );
      }
      final named = {for (final ref in data.entries) ref.name: ref};
      final head = named['HEAD'];
      if (head == null || head.targetCheckpointId != plan.headCheckpointId) {
        throw const ProjectHistoryImportException(
          'Archived HEAD does not match the validated checkpoint graph.',
        );
      }
      for (final ref in data.entries) {
        if (!ids.contains(ref.targetCheckpointId)) {
          throw ProjectHistoryImportException(
            'Missing checkpoint target for archived ref: ${ref.name}.',
          );
        }
      }
      final attachment = head.attachmentSpecified
          ? head.symbolicBranchName
          : (named['refs/heads/main']?.targetCheckpointId ==
                  head.targetCheckpointId
              ? 'refs/heads/main'
              : null);
      if (attachment != null) {
        final branch = named[attachment];
        if (branch == null || branch.kind != 'branch' ||
            branch.targetCheckpointId != head.targetCheckpointId) {
          throw const ProjectHistoryImportException(
            'Archived symbolic HEAD does not agree with its branch tip.',
          );
        }
      }
      return plan;
    } on CheckpointIntegrityException catch (error) {
      throw ProjectHistoryImportException(error.message);
    }
  }
}
