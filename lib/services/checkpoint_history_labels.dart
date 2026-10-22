import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

/// Plain-language copy for history screens. This maps persisted Git-inspired
/// references to UI descriptions without altering names, ownership or actions.
class CheckpointHistoryLabels {
  const CheckpointHistoryLabels._();

  static String referenceName(HistoryGraphReference ref) {
    if (ref.kind == 'head') return 'Current version';
    return ref.name.replaceFirst(RegExp(r'^refs/(heads|bookmarks)/'), '');
  }

  static String referenceLabel(HistoryGraphReference ref) {
    final name = referenceName(ref);
    if (ref.isAttached) return '$name (current branch)';
    return name;
  }

  static String status(CheckpointHistoryGraph graph) {
    if (graph.headCheckpointId == null) return 'No saved versions yet';
    if (graph.isDetached) {
      return 'Version #${graph.headCheckpointId} · Not on a branch';
    }
    final branchName = graph.attachedBranchName!
        .replaceFirst('refs/heads/', '');
    return 'Working on $branchName';
  }

  static String versionDetails(HistoryGraphNode node) {
    final parts = <String>['Version #${node.checkpointId}'];
    final parent = node.parentCheckpointId;
    parts.add(parent == null ? 'First saved version' : 'From #$parent');
    if (node.isHead) {
      parts.add('Current version');
    } else if (node.isHeadAncestor) {
      parts.add('On current path');
    }
    if (node.childCheckpointIds.length > 1) {
      parts.add('Branch point (${node.childCheckpointIds.length} paths)');
    }
    return parts.join(' · ');
  }

  static String checkoutTitle({required bool branch}) =>
      branch ? 'Switch to this branch?' : 'Restore this version?';

  static String checkoutMessage({
    required bool branch,
    required String target,
  }) {
    if (branch) {
      return 'Restore the saved subtitles at $target and make it your '
          'current branch. Other branches and bookmarks stay unchanged.';
    }
    return 'Restore the saved subtitles at $target without switching to '
        'a branch. Your existing branches and bookmarks stay unchanged. '
        'New edits continue separately from this version until you '
        'switch to or create a branch.';
  }
}
