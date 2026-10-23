import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_branch_view.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_lane_layout.dart';
import 'package:subtitle_studio/widgets/checkpoint_history_rail.dart';

Checkpoint _point(int id, int? parent, {bool active = false}) => Checkpoint(
  sessionId: 1,
  subtitleCollectionId: 9,
  timestamp: DateTime.utc(2026, 10, 22),
  operationType: 'edit',
  description: 'Edit $id',
  parentCheckpointId: parent,
  isActive: active,
  deltas: const [],
  snapshot: const [],
)..id = id;

HistoryRef _ref(String name, String kind, int id, {String? attached}) =>
    HistoryRef(
      sessionId: 1,
      subtitleCollectionId: 9,
      name: name,
      kind: kind,
      targetCheckpointId: id,
      symbolicBranchName: attached,
      createdAt: DateTime.utc(2026, 10, 22),
      updatedAt: DateTime.utc(2026, 10, 22),
    );

CheckpointHistoryGraph _fork() => CheckpointHistoryGraph.build(
  sessionId: 1,
  checkpoints: [
    _point(1, null),
    _point(2, 1),
    _point(3, 2, active: true),
    _point(4, 2),
  ],
  persistentRefs: [
    _ref('HEAD', 'head', 3, attached: 'refs/heads/main'),
    _ref('refs/heads/main', 'branch', 3),
    _ref('refs/heads/review', 'branch', 4),
    _ref('refs/bookmarks/draft', 'bookmark', 4),
  ],
);

void main() {
  test('selecting one path keeps shared ancestors but excludes sibling edits',
      () {
    final graph = _fork();
    final main = CheckpointHistoryBranchView.ancestorIds(
        graph, 'refs/heads/main');
    final review = CheckpointHistoryBranchView.ancestorIds(
        graph, 'refs/heads/review');
    expect(main, {1, 2, 3});
    expect(review, {1, 2, 4});
    expect(CheckpointHistoryBranchView.ancestorIds(
        graph, 'refs/heads/unknown'), isEmpty);

    final layout = CheckpointHistoryLaneLayout.fromGraph(
        graph, visibleCheckpointIds: review);
    expect(layout.laneCount, 1);
    expect(layout.rows.map((row) => row.node.checkpointId), [4, 2, 1]);
    expect(layout.rows.last.tracksBelow, isEmpty);
  });

  test('branch color ownership is distinct and active path owns shared trunk',
      () {
    final owners = CheckpointHistoryBranchView.displayOwners(_fork());
    expect(owners[3], 'refs/heads/main');
    expect(owners[4], 'refs/heads/review');
    expect(owners[2], 'refs/heads/main');
    expect(owners[1], 'refs/heads/main');
  });

  test('incomplete selection is rejected without drawing false edges', () {
    final graph = _fork();
    expect(() => CheckpointHistoryLaneLayout.fromGraph(graph,
        visibleCheckpointIds: {4, 1}), throwsStateError);
  });

  test('many branches reserve bounded space beside history cards', () {
    expect(CheckpointHistoryRailPainter.railWidth(1), 34);
    expect(CheckpointHistoryRailPainter.railWidth(5),
        lessThanOrEqualTo(80));
    expect(CheckpointHistoryRailPainter.railWidth(50), 80);
    expect(CheckpointHistoryRailPainter.railWidth(500), 80);
  });
}
