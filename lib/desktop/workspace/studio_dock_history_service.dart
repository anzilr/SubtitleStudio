import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'studio_dock_session_loader.dart';
import 'studio_dock_session_snapshot.dart';

/// A completed history navigation, with the actual persisted state after the
/// checkpoint checkout. The desktop editor never reconstructs subtitles from
/// its own displayed rows.
class StudioDockHistoryTransition {
  const StudioDockHistoryTransition(this.snapshot, this.graph);

  final StudioDockSessionSnapshot snapshot;
  final CheckpointHistoryGraph graph;
}

/// Connects Studio Dock to the application's existing transactional history.
///
/// The caller supplies both its displayed cue baseline and observed HEAD.
/// Stale windows cannot silently restore a different project's history or
/// overwrite changes made by another editor window. The underlying checkout
/// performs the final atomic HEAD and working-state verification.
class StudioDockHistoryService {
  const StudioDockHistoryService(this._loader, this._checkpoints);

  final StudioDockSessionLoader _loader;
  final CheckpointRepository _checkpoints;

  Future<CheckpointHistoryGraph> load(int sessionId) =>
      _checkpoints.getHistoryGraph(sessionId);

  Future<StudioDockHistoryTransition?> checkout({
    required StudioDockSessionSnapshot baseline,
    required int expectedHeadId,
    required int targetCheckpointId,
  }) async {
    if (targetCheckpointId == expectedHeadId) return null;

    // The loader checks session-to-collection ownership. Comparing every
    // persisted cue field also catches external edits without a new commit.
    final current = await _loader.load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
    if (!_sameSnapshot(baseline, current)) return null;

    final graph = await _checkpoints.getHistoryGraph(baseline.sessionId);
    if (graph.headCheckpointId != expectedHeadId ||
        !graph.nodes.any((node) => node.checkpointId == targetCheckpointId)) {
      return null;
    }

    final restored = await _checkpoints.checkoutCheckpoint(
      sessionId: baseline.sessionId,
      checkpointId: targetCheckpointId,
      ifCurrentHeadId: expectedHeadId,
    );
    if (!restored) return null;

    final snapshot = await _loader.load(
      sessionId: baseline.sessionId,
      collectionId: baseline.collectionId,
    );
    return StudioDockHistoryTransition(
      snapshot, await _checkpoints.getHistoryGraph(baseline.sessionId));
  }

  static bool _sameSnapshot(
    StudioDockSessionSnapshot left,
    StudioDockSessionSnapshot right,
  ) {
    if (left.sessionId != right.sessionId ||
        left.collectionId != right.collectionId ||
        left.fileName != right.fileName ||
        left.encoding != right.encoding ||
        left.cues.length != right.cues.length) return false;
    for (var i = 0; i < left.cues.length; i++) {
      final a = left.cues[i];
      final b = right.cues[i];
      if (a.index != b.index || a.start != b.start || a.end != b.end ||
          a.original != b.original || a.storedEdited != b.storedEdited ||
          a.marked != b.marked || a.comment != b.comment ||
          a.resolved != b.resolved) return false;
    }
    return true;
  }
}
