import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_history_lane_layout.dart';

Checkpoint _checkpoint(int id, int? parent, {bool active = false}) =>
    Checkpoint(
      sessionId: 1,
      subtitleCollectionId: 9,
      timestamp: DateTime.utc(2026, 10, 22),
      operationType: id == 1 ? 'snapshot' : 'edit',
      description: 'Change $id',
      parentCheckpointId: parent,
      isActive: active,
      checkpointType: 'snapshot',
      deltas: const [],
      snapshot: const [],
    )..id = id;

HistoryRef _ref(String name, String kind, int target,
        {String? attached}) =>
    HistoryRef(
      sessionId: 1,
      subtitleCollectionId: 9,
      name: name,
      kind: kind,
      targetCheckpointId: target,
      symbolicBranchName: attached,
      createdAt: DateTime.utc(2026, 10, 22),
      updatedAt: DateTime.utc(2026, 10, 22),
    );

CheckpointHistoryGraph _graph(List<Checkpoint> commits,
    {int headId = 1, String? attached = 'refs/heads/main',
      List<HistoryRef>? refs}) {
  return CheckpointHistoryGraph.build(
    sessionId: 1,
    checkpoints: commits,
    persistentRefs: refs ??
      [
        _ref('HEAD', 'head', headId, attached: attached),
        _ref('refs/heads/main', 'branch', headId),
      ],
  );
}

void main() {
  test('linear history uses one continuous lane through current HEAD', () {
    final graph = _graph([
      _checkpoint(3, 2, active: true),
      _checkpoint(2, 1),
      _checkpoint(1, null),
    ], headId: 3);
    final lanes = CheckpointHistoryLaneLayout.fromGraph(graph);
    expect(lanes.laneCount, 1);
    expect(lanes.rows.map((r) => r.node.checkpointId), [3, 2, 1]);
    expect(lanes.rows.map((r) => r.lane), [0, 0, 0]);
    expect(lanes.rows.map((r) => r.tracksAbove), [[], [0], [0]]);
    expect(lanes.rows.map((r) => r.tracksBelow), [[0], [0], []]);
    expect(lanes.rows.last.joiningLanes, [0]);
  });

  test('forked history joins only at the shared parent', () {
    final graph = _graph([
      _checkpoint(4, 2, active: true),
      _checkpoint(3, 2),
      _checkpoint(2, 1),
      _checkpoint(1, null),
    ], headId: 4, attached: 'refs/heads/feature', refs: [
      _ref('HEAD', 'head', 4, attached: 'refs/heads/feature'),
      _ref('refs/heads/main', 'branch', 3),
      _ref('refs/heads/feature', 'branch', 4),
    ]);
    final lanes = CheckpointHistoryLaneLayout.fromGraph(graph);
    expect(lanes.laneCount, 2);
    expect(lanes.rows.map((r) => r.node.checkpointId), [3, 4, 2, 1]);
    final tip = lanes.rows[1];
    expect(tip.node.checkpointId, 4);
    expect(tip.tracksAbove, [0]);
    expect(tip.tracksBelow, [0, 1]);
    final joint = lanes.rows[2];
    expect(joint.node.checkpointId, 2);
    expect(joint.joiningLanes, [0, 1]);
    expect(joint.tracksAbove, [0, 1]);
    expect(joint.tracksBelow, [0]);
    expect(joint.lane, 0);
  });

  test('detached HEAD graph still follows parent references', () {
    final graph = _graph([
      _checkpoint(1, null, active: true),
      _checkpoint(2, 1),
    ], headId: 1, attached: null, refs: [
      _ref('HEAD', 'head', 1),
      _ref('refs/heads/main', 'branch', 2),
    ]);
    expect(graph.isDetached, isTrue);
    final layout = CheckpointHistoryLaneLayout.fromGraph(graph);
    expect(layout.rows.map((r) => r.node.checkpointId), [2, 1]);
    expect(layout.rows.last.node.isHead, isTrue);
    expect(layout.rows.last.tracksBelow, isEmpty);
  });

  test('multiple fork tips never connect before their common parent', () {
    final graph = _graph([
      _checkpoint(1, null),
      _checkpoint(2, 1),
      _checkpoint(3, 2, active: true),
      _checkpoint(4, 2),
      _checkpoint(5, 2),
    ], headId: 3, refs: [
      _ref('HEAD', 'head', 3, attached: 'refs/heads/main'),
      _ref('refs/heads/main', 'branch', 3),
      _ref('refs/bookmarks/alternate-a', 'bookmark', 4),
      _ref('refs/bookmarks/alternate-b', 'bookmark', 5),
    ]);
    final layout = CheckpointHistoryLaneLayout.fromGraph(graph);
    expect(layout.laneCount, 3);
    final fork = layout.rows.firstWhere((r) => r.node.checkpointId == 2);
    expect(fork.joiningLanes.length, 3);
    expect(fork.tracksBelow, hasLength(1));
    for (final row in layout.rows.where((r) =>
        r.node.checkpointId == 3 || r.node.checkpointId == 4 ||
        r.node.checkpointId == 5)) {
      expect(row.joiningLanes, isEmpty);
    }
    expect(() => fork.tracksAbove.add(99), throwsUnsupportedError);
    expect(() => layout.rows.clear(), throwsUnsupportedError);
  });

  test('long history stays iterative and occupies one lane', () {
    final graph = _graph([
      for (var id = 1; id <= 1800; id++)
        _checkpoint(id, id == 1 ? null : id - 1, active: id == 1800),
    ], headId: 1800);
    final layout = CheckpointHistoryLaneLayout.fromGraph(graph);
    expect(layout.laneCount, 1);
    expect(layout.rows, hasLength(1800));
    expect(layout.rows.first.node.checkpointId, 1800);
    expect(layout.rows.last.node.checkpointId, 1);
  });
}
