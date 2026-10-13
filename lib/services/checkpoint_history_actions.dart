import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

/// Presentation-neutral commands for history views. Both the existing mobile
/// history surface and a future desktop pane can depend on this API.
///
/// Every mutation goes through the transactional CheckpointRepository; the
/// graph is refreshed from durable state after a successful operation.
/// A rejected checkout returns null so the UI can display a warning without
/// pretending that the requested branch or commit was activated.
class CheckpointHistoryActions {
  final CheckpointRepository _repository;
  final int sessionId;

  const CheckpointHistoryActions(this._repository, {required this.sessionId});

  Future<CheckpointHistoryGraph> load() =>
      _repository.getHistoryGraph(sessionId);

  Future<CheckpointHistoryGraph> createBranch({
    required String name,
    required int checkpointId,
  }) async {
    await _repository.createBranch(
      sessionId: sessionId, name: name, checkpointId: checkpointId);
    return load();
  }

  Future<CheckpointHistoryGraph> createBookmark({
    required String name,
    required int checkpointId,
  }) async {
    await _repository.createBookmark(
      sessionId: sessionId, name: name, checkpointId: checkpointId);
    return load();
  }

  Future<CheckpointHistoryGraph> renameReference({
    required String name,
    required String newName,
  }) async {
    await _repository.renameReference(
      sessionId: sessionId, name: name, newName: newName);
    return load();
  }

  Future<CheckpointHistoryGraph> deleteReference(String name) async {
    await _repository.deleteReference(sessionId: sessionId, name: name);
    return load();
  }

  Future<CheckpointHistoryGraph?> checkoutBranch(String name) async {
    if (!await _repository.checkoutBranch(sessionId: sessionId, name: name)) {
      return null;
    }
    return load();
  }

  /// Direct commit checkout deliberately detaches HEAD (Checkpoint 70).
  Future<CheckpointHistoryGraph?> checkoutCommit(int checkpointId) async {
    if (!await _repository.checkoutCheckpoint(
        sessionId: sessionId, checkpointId: checkpointId)) {
      return null;
    }
    return load();
  }
}
