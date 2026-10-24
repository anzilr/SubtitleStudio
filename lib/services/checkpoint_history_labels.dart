import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

/// Plain-language copy for history screens. This maps persisted Git-inspired
/// references to UI descriptions without altering names, ownership or actions.
class CheckpointHistoryLabels {
  const CheckpointHistoryLabels._();

  static String referenceName(HistoryGraphReference ref) {
    if (ref.kind == 'head') return 'Current point';
    // The protected built-in reference stays 'refs/heads/main' in storage.
    // Only its visible name changes: subtitle editors should not need to
    // understand Git's default branch name.
    if (ref.kind == 'branch' && ref.name == 'refs/heads/main') {
      return 'Main path';
    }
    return ref.name.replaceFirst(RegExp(r'^refs/(heads|bookmarks)/'), '');
  }

  static String referenceLabel(HistoryGraphReference ref) {
    final name = referenceName(ref);
    if (ref.isAttached) return '$name · In use';
    return name;
  }

  static String status(CheckpointHistoryGraph graph) {
    if (graph.headCheckpointId == null) return 'No history points yet';
    if (graph.isDetached) {
      return 'Editing from point #${graph.headCheckpointId} · Separate branch';
    }
    final attached = graph.attachedBranchName!;
    final name = attached == 'refs/heads/main'
        ? 'Main path'
        : attached.replaceFirst('refs/heads/', '');
    return 'Editing: $name';
  }

  static String versionDetails(HistoryGraphNode node) {
    final parts = <String>['Point #${node.checkpointId}'];
    final parent = node.parentCheckpointId;
    parts.add(parent == null ? 'First history point' : 'From #$parent');
    if (node.isHead) {
      parts.add('Current point');
    } else if (node.isHeadAncestor) {
      parts.add('Earlier on this path');
    }
    if (node.childCheckpointIds.length > 1) {
      parts.add('History split (${node.childCheckpointIds.length} paths)');
    }
    return parts.join(' · ');
  }

  static final RegExp _edited = RegExp(r'^Edited line (\d+)$');
  static final RegExp _added = RegExp(r'^Added line at position (\d+)$');
  static final RegExp _deleted = RegExp(r'^Deleted line (\d+)$');
  static final RegExp _split = RegExp(r'^Split line (\d+)$');
  static final RegExp _merged = RegExp(r'^Merged lines (\d+) and (\d+)$');
  static final RegExp _marked = RegExp(r'^Marked line (\d+)$');
  static final RegExp _unmarked = RegExp(r'^Unmarked line (\d+)$');
  static final RegExp _comment = RegExp(r'^Updated comment on line (\d+)$');
  static final RegExp _reviewNotes =
      RegExp(r'^Updated review notes on line (\d+)$');
  static final RegExp _resolved = RegExp(r'^Updated resolution of line (\d+)$');

  static String? _matchOne(String title, RegExp pattern, String prefix,
      {String suffix = ''}) {
    final match = pattern.firstMatch(title);
    return match == null ? null : '$prefix ${match[1]}$suffix';
  }

  static String? _matchMerge(String title) {
    final match = _merged.firstMatch(title);
    return match == null ? null
        : 'Combined subtitles ${match[1]} and ${match[2]}';
  }

  static String? _matchAnnotation(String title) =>
      _matchOne(title, _marked, 'Marked subtitle',
          suffix: ' for review') ??
      _matchOne(title, _unmarked, 'Removed review mark from subtitle') ??
      _matchOne(title, _comment, 'Updated note on subtitle') ??
      _matchOne(title, _reviewNotes, 'Updated review notes on subtitle') ??
      _matchOne(title, _resolved, 'Updated review status of subtitle');

  static String? _matchEdit(String title) =>
      _matchOne(title, _edited, 'Edited subtitle') ??
      _matchAnnotation(title);

  /// Display-only title for an edit-history entry.
  ///
  /// The database keeps its original operation type and description, because
  /// imported projects, undo/redo, and existing history formats depend on
  /// those fields. Only known machine-generated descriptions are rewritten.
  /// Manual names and unfamiliar descriptions must be displayed verbatim.
  static String entryTitle({
    required String operationType,
    required String description,
  }) {
    if (operationType == 'manual') {
      return description == 'Manual checkpoint' || description.trim().isEmpty
          ? 'Save point created'
          : description;
    }

    final title = description.trim();
    if (title == 'Initial state' && operationType == 'snapshot') {
      return 'Project started';
    }
    if (title == 'Snapshot' && operationType == 'snapshot') {
      return 'Saved project point';
    }
    if (title == 'Captured external subtitle changes' &&
        operationType == 'sync') {
      return 'Saved changes made outside the editor';
    }


    // Only translate well-known generated descriptions, scoped by the
    // persisted operation type. Keep all custom/imported strings intact.
    final pattern = switch (operationType) {
      'edit' => _matchEdit(title),
      'add' => _matchOne(title, _added, 'Added subtitle'),
      'delete' => _matchOne(title, _deleted, 'Deleted subtitle'),
      'split' => _matchOne(title, _split, 'Split subtitle', suffix: ' into two'),
      'merge' => _matchMerge(title),
      'annotation' => _matchAnnotation(title),
      _ => null,
    };
    if (pattern != null) return pattern;

    if (title.isEmpty) {
      return switch (operationType) {
        'add' => 'Added subtitles',
        'delete' => 'Deleted subtitles',
        'split' => 'Split a subtitle',
        'merge' => 'Combined subtitles',
        'edit' => 'Edited subtitles',
        'effect' => 'Applied subtitle effect',
        'sync' => 'Updated subtitle timing',
        'snapshot' => 'Saved project point',
        _ => 'Saved change',
      };
    }
    return title;
  }

  /// The small marker shown on the classic timeline.
  static String entryBadge({
    required String operationType,
    required String checkpointType,
  }) {
    if (operationType == 'manual') return 'Save point';
    if (checkpointType == 'snapshot') return 'Saved point';
    return 'Edit';
  }

  static String checkoutTitle({required bool branch}) =>
      branch ? 'Switch to this path?' : 'Restore this point?';

  static String checkoutMessage({
    required bool branch,
    required String target,
  }) {
    if (branch) {
      return 'Open the saved subtitles from $target and continue editing '
          'there. Your other editing paths and bookmarks stay available.';
    }
    return 'Open the saved subtitles from $target on a separate editing '
        'path. Your existing editing paths and bookmarks stay available. '
        'New edits continue from this point without changing the names '
        'or saved positions of your other paths.';
  }
}
