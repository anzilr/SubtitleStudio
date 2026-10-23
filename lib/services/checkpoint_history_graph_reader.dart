import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_graph.dart';
import 'package:subtitle_studio/services/history_ref_repository.dart';

/// Loads one consistent history+refs snapshot for mobile or desktop UIs.
/// Migration is an explicit separate transaction; neither the graph builder
/// nor the UI is permitted to write checkpoint/reference rows.
class CheckpointHistoryGraphReader {
  final Isar _isar;
  final HistoryRefRepository _refs;

  CheckpointHistoryGraphReader(Isar isar)
      : _isar = isar,
        _refs = HistoryRefRepository(isar);

  Future<CheckpointHistoryGraph> load(int sessionId) async {
    await _refs.ensureMigrated(sessionId);
    return _isar.txn(() async {
      final checkpoints = await _isar.checkpoints
          .filter().sessionIdEqualTo(sessionId).findAll();
      final refs = await _isar.historyRefs
          .filter().sessionIdEqualTo(sessionId).findAll();
      return CheckpointHistoryGraph.build(
        sessionId: sessionId,
        checkpoints: checkpoints,
        persistentRefs: refs,
      );
    });
  }
}
