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
        _reference('HEAD', 'head')), 'Current point');
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
        'Main path · In use');
    expect(CheckpointHistoryLabels.referenceLabel(inactive), 'alternate');
    // Git-style storage and protection stay exact despite friendlier UI.
    expect(CheckpointHistoryLabels.referenceName(attached), 'Main path');
    expect(CheckpointHistoryLabels.referenceLabel(
      _reference('refs/heads/main', 'branch')), 'Main path');
    expect(CheckpointHistoryLabels.referenceLabel(
      _reference('refs/heads/review', 'branch', attached: true)),
      'review · In use');
    expect(attached.name, 'refs/heads/main');
    expect(attached.canDelete, isFalse);
  });

  test('version metadata describes current and ancestor versions', () {
    expect(CheckpointHistoryLabels.versionDetails(_node(
      isHead: true,
    )), 'Point #4 · From #2 · Current point');
    expect(CheckpointHistoryLabels.versionDetails(_node(
      isHeadAncestor: true,
    )), 'Point #4 · From #2 · Earlier on this path');
    expect(CheckpointHistoryLabels.versionDetails(_node(
      id: 1, parentId: null,
    )), 'Point #1 · First history point');
  });

  test('branch points describe actual child count without Git jargon', () {
    final node = _node(children: [5, 6, 7]);
    expect(CheckpointHistoryLabels.versionDetails(node),
        'Point #4 · From #2 · History split (3 paths)');
  });

  test('internal default branch never appears as raw UI text', () {
    final protectedMain = _reference('refs/heads/main', 'branch',
        attached: true);
    final label = CheckpointHistoryLabels.referenceLabel(protectedMain);
    expect(label, 'Main path · In use');
    expect(label, isNot(contains('main')));
    expect(label, isNot(contains('current branch')));
    expect(protectedMain.name, 'refs/heads/main');
    expect(protectedMain.canRename, isFalse);
    expect(protectedMain.canDelete, isFalse);
  });

  test('switch confirmation promises to preserve other named paths', () {
    expect(CheckpointHistoryLabels.checkoutTitle(branch: true),
        'Switch to this path?');
    final body = CheckpointHistoryLabels.checkoutMessage(
      branch: true,
      target: '"Main path"',
    );
    expect(body, contains('continue editing there'));
    expect(body, contains('other editing paths and bookmarks stay available'));
    expect(body, isNot(contains('detach HEAD')));
  });

  test('restore confirmation explains separate edits off a branch', () {
    expect(CheckpointHistoryLabels.checkoutTitle(branch: false),
        'Restore this point?');
    final body = CheckpointHistoryLabels.checkoutMessage(
      branch: false,
      target: 'point #4',
    );
    expect(body, contains('on a separate editing path'));
    expect(body, contains('New edits continue from this point'));
    expect(body, contains('editing paths and bookmarks stay available'));
  });
}
