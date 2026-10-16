import 'package:subtitle_studio/database/models/models.dart';

/// Immutable history data for any timeline/graph presentation.
///
/// No UI or Isar dependency is needed to arrange the graph. Persistent refs
/// are copied to view models so a caller cannot mutate them accidentally.
class HistoryGraphReference {
  final String name;
  final String kind;
  final int checkpointId;
  final bool isAttached;
  final bool canRename;
  final bool canDelete;

  const HistoryGraphReference({
    required this.name,
    required this.kind,
    required this.checkpointId,
    required this.isAttached,
    required this.canRename,
    required this.canDelete,
  });
}

class HistoryGraphNode {
  final int checkpointId;
  final int? parentCheckpointId;
  final List<int> childCheckpointIds;
  final int depth;
  final DateTime timestamp;
  final String operationType;
  final String description;
  final bool isHead;
  final bool isHeadAncestor;
  final List<HistoryGraphReference> references;

  const HistoryGraphNode({
    required this.checkpointId,
    required this.parentCheckpointId,
    required this.childCheckpointIds,
    required this.depth,
    required this.timestamp,
    required this.operationType,
    required this.description,
    required this.isHead,
    required this.isHeadAncestor,
    required this.references,
  });
}

/// A deterministic topological timeline, with parent/child edges and labels.
///
/// Nodes are ordered by depth first, then timestamp and ID. Depth ordering
/// guarantees parents precede children even when device clocks go backwards.
/// A rendering widget may calculate visual lanes without rewriting history.
class CheckpointHistoryGraph {
  final int? headCheckpointId;
  final String? attachedBranchName;
  final List<HistoryGraphNode> nodes;
  final List<HistoryGraphReference> references;

  const CheckpointHistoryGraph._({
    required this.headCheckpointId,
    required this.attachedBranchName,
    required this.nodes,
    required this.references,
  });

  bool get isDetached => headCheckpointId != null && attachedBranchName == null;
  List<HistoryGraphNode> get newestFirst =>
      List<HistoryGraphNode>.unmodifiable(nodes.reversed);

  static CheckpointHistoryGraph build({
    required int sessionId,
    required List<Checkpoint> checkpoints,
    required List<HistoryRef> persistentRefs,
  }) {
    if (checkpoints.isEmpty && persistentRefs.isEmpty) {
      return const CheckpointHistoryGraph._(
        headCheckpointId: null,
        attachedBranchName: null,
        nodes: <HistoryGraphNode>[],
        references: <HistoryGraphReference>[],
      );
    }
    if (checkpoints.isEmpty || persistentRefs.isEmpty) {
      throw StateError('Checkpoint history and its references disagree.');
    }

    final byId = <int, Checkpoint>{};
    final collectionId = checkpoints.first.subtitleCollectionId;
    for (final checkpoint in checkpoints) {
      if (checkpoint.id <= 0 ||
          checkpoint.sessionId != sessionId ||
          checkpoint.subtitleCollectionId != collectionId ||
          byId.containsKey(checkpoint.id)) {
        throw StateError('Invalid or mixed-session checkpoint graph.');
      }
      byId[checkpoint.id] = checkpoint;
    }

    final children = <int, List<int>>{};
    for (final checkpoint in checkpoints) {
      final parent = checkpoint.parentCheckpointId;
      if (parent != null) {
        if (!byId.containsKey(parent)) {
          throw StateError('Checkpoint has a missing parent.');
        }
        children.putIfAbsent(parent, () => <int>[]).add(checkpoint.id);
      }
    }

    // Iterative depth calculation: avoid recursion on long edit histories.
    final depth = <int, int>{};
    for (final checkpoint in checkpoints) {
      if (depth.containsKey(checkpoint.id)) continue;
      final path = <int>[];
      final visiting = <int>{};
      int? current = checkpoint.id;
      while (current != null && !depth.containsKey(current)) {
        if (!visiting.add(current)) {
          throw StateError('Checkpoint history contains a parent cycle.');
        }
        path.add(current);
        current = byId[current]!.parentCheckpointId;
      }
      var nextDepth = current == null ? 0 : depth[current]! + 1;
      for (final id in path.reversed) {
        depth[id] = nextDepth++;
      }
    }

    int compareId(int a, int b) {
      final left = byId[a]!;
      final right = byId[b]!;
      final byTime = left.timestamp.compareTo(right.timestamp);
      return byTime != 0 ? byTime : a.compareTo(b);
    }

    for (final ids in children.values) {
      ids.sort(compareId);
    }
    final byName = <String, HistoryRef>{};
    for (final ref in persistentRefs) {
      if (ref.sessionId != sessionId ||
          ref.subtitleCollectionId != collectionId ||
          ref.schemaVersion != 1 ||
          ref.name.isEmpty ||
          !byId.containsKey(ref.targetCheckpointId) ||
          byName.containsKey(ref.name) ||
          !(ref.kind == 'head' && ref.name == 'HEAD' ||
            ref.kind == 'branch' && ref.name.startsWith('refs/heads/') ||
            ref.kind == 'bookmark' &&
                ref.name.startsWith('refs/bookmarks/'))) {
        throw StateError('Invalid persistent history reference.');
      }
      byName[ref.name] = ref;
    }
    if (persistentRefs.where((ref) => ref.kind == 'head').length != 1) {
      throw StateError('History requires exactly one HEAD reference.');
    }
    final head = byName['HEAD'];
    if (head == null) throw StateError('History is missing HEAD.');
    final attached = head.symbolicBranchName;
    if (attached != null &&
        (byName[attached]?.kind != 'branch' ||
         byName[attached]?.targetCheckpointId != head.targetCheckpointId)) {
      throw StateError('Attached branch and HEAD disagree.');
    }
    if (checkpoints.where((cp) => cp.isActive).length != 1 ||
        !byId[head.targetCheckpointId]!.isActive) {
      throw StateError('Persisted HEAD and active checkpoint disagree.');
    }

    final refs = persistentRefs.map((ref) {
      final isAttached = attached != null && ref.name == attached;
      final isHead = ref.name == 'HEAD';
      final isMain = ref.name == 'refs/heads/main';
      return HistoryGraphReference(
        name: ref.name,
        kind: ref.kind,
        checkpointId: ref.targetCheckpointId,
        isAttached: isAttached,
        // UI affordances only; transaction checks remain authoritative.
        canRename: !isHead && !isMain,
        canDelete: !isHead && !isMain && !isAttached,
      );
    }).toList()
      ..sort((a, b) {
        if (a.name == 'HEAD') return -1;
        if (b.name == 'HEAD') return 1;
        return a.name.compareTo(b.name);
      });
    final immutableRefs = List<HistoryGraphReference>.unmodifiable(refs);
    final refsByCheckpoint = <int, List<HistoryGraphReference>>{};
    for (final ref in immutableRefs) {
      refsByCheckpoint
          .putIfAbsent(ref.checkpointId, () => <HistoryGraphReference>[])
          .add(ref);
    }

    final headPath = <int>{};
    int? current = head.targetCheckpointId;
    while (current != null) {
      if (!headPath.add(current)) {
        throw StateError('HEAD ancestry has a cycle.');
      }
      current = byId[current]!.parentCheckpointId;
    }

    final sorted = [...checkpoints]..sort((a, b) {
      final level = depth[a.id]!.compareTo(depth[b.id]!);
      return level != 0 ? level : compareId(a.id, b.id);
    });
    return CheckpointHistoryGraph._(
      headCheckpointId: head.targetCheckpointId,
      attachedBranchName: attached,
      references: immutableRefs,
      nodes: List<HistoryGraphNode>.unmodifiable([
        for (final checkpoint in sorted)
          HistoryGraphNode(
            checkpointId: checkpoint.id,
            parentCheckpointId: checkpoint.parentCheckpointId,
            childCheckpointIds: List<int>.unmodifiable(
                children[checkpoint.id] ?? const <int>[]),
            depth: depth[checkpoint.id]!,
            timestamp: checkpoint.timestamp,
            operationType: checkpoint.operationType,
            description: checkpoint.description,
            isHead: checkpoint.id == head.targetCheckpointId,
            isHeadAncestor: headPath.contains(checkpoint.id),
            references: List<HistoryGraphReference>.unmodifiable(
                refsByCheckpoint[checkpoint.id] ??
                    const <HistoryGraphReference>[]),
          ),
      ]),
    );
  }
}
