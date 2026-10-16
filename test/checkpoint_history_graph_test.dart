import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

Checkpoint _checkpoint(int id, int? parent, {
  int sessionId = 1,
  bool active = false,
  DateTime? timestamp,
}) => Checkpoint(
  sessionId: sessionId,
  subtitleCollectionId: 9,
  timestamp: timestamp ?? DateTime.utc(2026, 10, 13),
  operationType: id == 1 ? 'snapshot' : 'edit',
  description: 'Commit $id',
  parentCheckpointId: parent,
  isActive: active,
  checkpointType: 'snapshot',
  deltas: const [],
  snapshot: const [],
)..id = id;

HistoryRef _ref(String name, String kind, int target, {
  String? attached,
}) => HistoryRef(
  sessionId: 1,
  subtitleCollectionId: 9,
  name: name,
  kind: kind,
  targetCheckpointId: target,
  symbolicBranchName: attached,
  createdAt: DateTime.utc(2026, 10, 13),
  updatedAt: DateTime.utc(2026, 10, 13),
);

void main() {
  test('empty history has a useful empty, immutable view', () {
    final graph = CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: [], persistentRefs: []);
    expect(graph.nodes, isEmpty);
    expect(graph.references, isEmpty);
    expect(graph.headCheckpointId, isNull);
    expect(graph.isDetached, isFalse);
    expect(() => graph.nodes.clear(), throwsUnsupportedError);
  });

  test('forks are topological and retain attached labels and HEAD ancestry', () {
    final graph = CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [
        _checkpoint(4, 2, active: true,
            timestamp: DateTime.utc(2025)),
        _checkpoint(3, 2),
        _checkpoint(2, 1),
        _checkpoint(1, null),
      ],
      persistentRefs: [
        _ref('refs/bookmarks/review', 'bookmark', 2),
        _ref('refs/heads/feature', 'branch', 4),
        _ref('refs/heads/main', 'branch', 3),
        _ref('HEAD', 'head', 4, attached: 'refs/heads/feature'),
      ],
    );
    expect(graph.nodes.map((n) => n.checkpointId), [1, 2, 4, 3]);
    expect(graph.nodes.map((n) => n.depth), [0, 1, 2, 2]);
    expect(graph.nodes[1].childCheckpointIds, [4, 3]);
    expect(graph.headCheckpointId, 4);
    expect(graph.attachedBranchName, 'refs/heads/feature');
    expect(graph.isDetached, isFalse);
    expect(graph.nodes.where((n) => n.isHeadAncestor)
        .map((n) => n.checkpointId), [1, 2, 4]);
    expect(graph.nodes[2].references.map((r) => r.name),
        ['HEAD', 'refs/heads/feature']);
    final feature = graph.references.firstWhere(
        (r) => r.name == 'refs/heads/feature');
    expect(feature.isAttached, isTrue);
    expect(feature.canRename, isTrue);
    expect(feature.canDelete, isFalse);
    expect(graph.references.firstWhere(
        (r) => r.name == 'refs/heads/main').canDelete, isFalse);
    expect(() => graph.nodes[1].childCheckpointIds.add(7),
        throwsUnsupportedError);
    expect(() => graph.nodes[2].references.clear(), throwsUnsupportedError);
  });

  test('direct checkout view is detached while branches remain fixed', () {
    final graph = CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [_checkpoint(1, null, active: true), _checkpoint(2, 1)],
      persistentRefs: [
        _ref('HEAD', 'head', 1),
        _ref('refs/heads/main', 'branch', 2),
      ],
    );
    expect(graph.isDetached, isTrue);
    expect(graph.headCheckpointId, 1);
    expect(graph.references.where((r) => r.isAttached), isEmpty);
    expect(graph.nodes.last.references.single.name, 'refs/heads/main');
  });

  test('broken edges, cycles, duplicate IDs and foreign owners fail closed', () {
    final refs = [_ref('HEAD', 'head', 1), _ref('refs/heads/main', 'branch', 1)];
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [_checkpoint(1, 99, active: true)],
      persistentRefs: refs), throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [_checkpoint(1, 2, active: true), _checkpoint(2, 1)],
      persistentRefs: refs), throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [_checkpoint(1, null, active: true),
                    _checkpoint(1, null, active: true)],
      persistentRefs: refs), throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1,
      checkpoints: [_checkpoint(1, null, sessionId: 2, active: true)],
      persistentRefs: refs), throwsStateError);
  });

  test('stale or corrupt HEAD and refs cannot produce a misleading graph', () {
    final commits = [_checkpoint(1, null, active: true), _checkpoint(2, 1)];
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: commits,
      persistentRefs: [_ref('HEAD', 'head', 2),
                       _ref('refs/heads/main', 'branch', 1)]),
      throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: commits,
      persistentRefs: [_ref('HEAD', 'head', 1, attached: 'refs/heads/main'),
                       _ref('refs/heads/main', 'branch', 2)]),
      throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: commits,
      persistentRefs: [_ref('HEAD', 'head', 1), _ref('HEAD', 'head', 1)]),
      throwsStateError);
    expect(() => CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: commits,
      persistentRefs: [_ref('HEAD', 'head', 1), _ref('refs/heads/main',
           'branch', 200)]),
      throwsStateError);
  });

  test('long ancestry can be arranged without recursive stack overflow', () {
    final checkpoints = [
      for (var id = 1; id <= 2000; id++)
        _checkpoint(id, id == 1 ? null : id - 1, active: id == 2000),
    ];
    final graph = CheckpointHistoryGraph.build(
      sessionId: 1, checkpoints: checkpoints.reversed.toList(),
      persistentRefs: [
        _ref('HEAD', 'head', 2000, attached: 'refs/heads/main'),
        _ref('refs/heads/main', 'branch', 2000),
      ],
    );
    expect(graph.nodes.last.depth, 1999);
    expect(graph.nodes.where((n) => n.isHeadAncestor), hasLength(2000));
  });
}
