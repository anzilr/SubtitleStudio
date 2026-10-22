import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

/// One visible (newest-first) history row with the tracks crossing its
/// upper/lower boundaries. Tracks join the selected node only when their
/// actual child checkpoint names this node as its parent.
class CheckpointHistoryLaneRow {
  final HistoryGraphNode node;
  final int lane;
  final List<int> tracksAbove;
  final List<int> tracksBelow;
  final List<int> joiningLanes;

  const CheckpointHistoryLaneRow({
    required this.node,
    required this.lane,
    required this.tracksAbove,
    required this.tracksBelow,
    required this.joiningLanes,
  });
}

/// Layout only: never edits persisted checkpoints or named references.
///
/// The input graph is parent-before-child, and rows are emitted newest-first
/// for ListView.builder. The frontier maps each still-open visual track to
/// the parent checkpoint it must eventually meet. This prevents unrelated
/// parallel branches from being connected merely because their timestamps
/// or depths happen to match.
class CheckpointHistoryLaneLayout {
  final List<CheckpointHistoryLaneRow> rows;
  final int laneCount;

  const CheckpointHistoryLaneLayout._(this.rows, this.laneCount);

  static CheckpointHistoryLaneLayout fromGraph(
      CheckpointHistoryGraph graph) {
    final frontier = <int, int>{};
    final rows = <CheckpointHistoryLaneRow>[];
    var highestLane = -1;

    for (final node in graph.nodes.reversed) {
      final above = frontier.keys.toList()..sort();
      final joining = above
          .where((lane) => frontier[lane] == node.checkpointId)
          .toList();

      int lane;
      if (joining.isNotEmpty) {
        // Retain the oldest visible lane as branches converge. This keeps
        // the main timeline relatively straight rather than jumping tracks.
        lane = joining.first;
        for (final childLane in joining) {
          frontier.remove(childLane);
        }
      } else {
        lane = 0;
        while (frontier.containsKey(lane)) {
          lane++;
        }
      }

      final parentId = node.parentCheckpointId;
      if (parentId != null) {
        frontier[lane] = parentId;
      }
      final below = frontier.keys.toList()..sort();
      if (lane > highestLane) highestLane = lane;
      for (final activeLane in below) {
        if (activeLane > highestLane) highestLane = activeLane;
      }
      rows.add(CheckpointHistoryLaneRow(
        node: node,
        lane: lane,
        tracksAbove: List<int>.unmodifiable(above),
        tracksBelow: List<int>.unmodifiable(below),
        joiningLanes: List<int>.unmodifiable(joining),
      ));
    }

    // If an input graph has a missing parent, do not silently draw an
    // unconnected tail that could misrepresent the actual history.
    if (frontier.isNotEmpty) {
      throw StateError('History graph has unresolved parent connections.');
    }
    return CheckpointHistoryLaneLayout._(
      List<CheckpointHistoryLaneRow>.unmodifiable(rows),
      highestLane + 1,
    );
  }
}
