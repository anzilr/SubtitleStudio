import 'package:subtitle_studio/services/checkpoint_history_graph.dart';

/// Read-only branch ancestry for history presentation. A path includes its
/// shared ancestors, never commits that exist solely on a sibling path.
class CheckpointHistoryBranchView {
  const CheckpointHistoryBranchView._();

  static Set<int> ancestorIds(
      CheckpointHistoryGraph graph, String branchName) {
    final references = graph.references.where((ref) =>
        ref.kind == 'branch' && ref.name == branchName);
    if (references.isEmpty) return const <int>{};

    final byId = {for (final node in graph.nodes) node.checkpointId: node};
    final result = <int>{};
    int? id = references.first.checkpointId;
    while (id != null && result.add(id)) {
      id = byId[id]?.parentCheckpointId;
    }
    return Set<int>.unmodifiable(result);
  }

  /// Give each node the first applicable named path, preferring the active
  /// path and then the built-in main path on shared ancestry. This requires
  /// at most one ownership assignment per node, even with many branches.
  static Map<int, String> displayOwners(CheckpointHistoryGraph graph) {
    final refs = graph.references.where((ref) => ref.kind == 'branch').toList()
      ..sort((a, b) {
        int priority(HistoryGraphReference ref) =>
            ref.isAttached ? 0 : ref.name == 'refs/heads/main' ? 1 : 2;
        final order = priority(a).compareTo(priority(b));
        return order != 0 ? order : a.name.compareTo(b.name);
      });
    final byId = {for (final node in graph.nodes) node.checkpointId: node};
    final owners = <int, String>{};
    for (final ref in refs) {
      int? id = ref.checkpointId;
      while (id != null && !owners.containsKey(id)) {
        owners[id] = ref.name;
        id = byId[id]?.parentCheckpointId;
      }
    }
    return Map<int, String>.unmodifiable(owners);
  }
}
