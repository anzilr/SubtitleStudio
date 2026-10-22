import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';

HistoryGraphReference _reference(
  String name,
  String kind, {
  bool attached = false,
}) =>
    HistoryGraphReference(
      name: name,
      kind: kind,
      checkpointId: 4,
      isAttached: attached,
      canRename: false,
      canDelete: false,
    );

HistoryGraphNode _node({
  int id = 4,
  int? parentId = 2,
  bool isHead = false,
  bool isHeadAncestor = false,
  List<int> children = const [],
}) =>
    HistoryGraphNode(
      checkpointId: id,
      parentCheckpointId: parentId,
      childCheckpointIds: children,
      depth: 2,
      timestamp: DateTime.utc(2026, 10, 22),
      operationType: 'edit',
      description: 'Edited subtitle line',
      isHead: isHead,
      isHeadAncestor: isHeadAncestor,
      references: const [],
    );

void main() {
  test('persistent names are preserved while HEAD gets a readable label',
      () {
    expect(CheckpointHistoryLabels.referenceName(
        _reference('HEAD', 'head')), 'Current version');
    expect(CheckpointHistoryLabels.referenceName(
        _reference('refs/heads/feature/custom', 'branch')),
        'feature/custom');
    expect(CheckpointHistoryLabels.referenceName(
        _reference('refs/bookmarks/review', 'bookmark')), 'review');
  });

  test('active branch is clearly marked without changing the reference',
      () {
    final attached = _reference(
      'refs/heads/main', 'branch', attached: true,
    );
    final inactive = _reference('refs/heads/alternate', 'branch');
    expect(CheckpointHistoryLabels.referenceLabel(attached),
        'main (current branch)');
    expect(CheckpointHistoryLabels.referenceLabel(inactive), 'alternate');
    expect(attached.name, 'refs/heads/main');
    expect(attached.canDelete, isFalse);
  });

  test('version metadata describes current and ancestor versions', () {
    expect(CheckpointHistoryLabels.versionDetails(_node(
      isHead: true,
    )), 'Version #4 · From #2 · Current version');
    expect(CheckpointHistoryLabels.versionDetails(_node(
      isHeadAncestor: true,
    )), 'Version #4 · From #2 · On current path');
    expect(CheckpointHistoryLabels.versionDetails(_node(
      id: 1, parentId: null,
    )), 'Version #1 · First saved version');
  });

  test('branch points describe actual child count without Git jargon', () {
    final node = _node(children: [5, 6, 7]);
    expect(CheckpointHistoryLabels.versionDetails(node),
        'Version #4 · From #2 · Branch point (3 paths)');
  });

  test('switch confirmation promises to preserve other named paths', () {
    expect(CheckpointHistoryLabels.checkoutTitle(branch: true),
        'Switch to this branch?');
    final body = CheckpointHistoryLabels.checkoutMessage(
      branch: true,
      target: 'branch "main"',
    );
    expect(body, contains('current branch'));
    expect(body, contains('Other branches and bookmarks stay unchanged'));
    expect(body, isNot(contains('detach HEAD')));
  });

  test('restore confirmation explains separate edits off a branch', () {
    expect(CheckpointHistoryLabels.checkoutTitle(branch: false),
        'Restore this version?');
    final body = CheckpointHistoryLabels.checkoutMessage(
      branch: false,
      target: 'version #4',
    );
    expect(body, contains('without switching to a branch'));
    expect(body, contains('New edits continue separately'));
    expect(body, contains('branches and bookmarks stay unchanged'));
  });
}
