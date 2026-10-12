import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

Checkpoint _checkpoint({
  required int id,
  required int? parentId,
  required String operation,
  bool head = false,
  bool v2 = true,
  int sessionId = 1,
}) => Checkpoint(
  sessionId: sessionId,
  subtitleCollectionId: 3,
  timestamp: DateTime.utc(2026, 10, 12).add(Duration(minutes: id)),
  operationType: operation,
  description: 'Commit $id',
  parentCheckpointId: parentId,
  isActive: head,
  checkpointType: 'snapshot',
  deltas: const <SubtitleLineDelta>[],
  snapshot: const <SubtitleLine>[],
  metadata: v2 ? CheckpointHistoryMetadata.encodePostOperation() : null,
)..id = id;

void main() {
  test('HEAD, alternate branch tips and manual bookmarks are distinct refs',
      () {
    final commits = [
      _checkpoint(id: 1, parentId: null, operation: 'snapshot'),
      _checkpoint(id: 2, parentId: 1, operation: 'edit'),
      _checkpoint(id: 3, parentId: 2, operation: 'edit'),
      _checkpoint(id: 4, parentId: 2, operation: 'manual'),
      _checkpoint(id: 5, parentId: 4, operation: 'edit', head: true),
    ];

    final refs = CheckpointReferenceCatalog.fromHistory(commits);
    expect(
      refs.map((r) => (r.name, r.checkpointId, r.kind)).toList(),
      [
        ('HEAD', 5, CheckpointReferenceKind.head),
        ('refs/heads/alternate-3', 3, CheckpointReferenceKind.branchTip),
        ('refs/bookmarks/manual-4', 4, CheckpointReferenceKind.manualBookmark),
      ],
    );
    expect(commits.where((c) => c.isActive).map((c) => c.id), [5]);
  });

  test('legacy multiple active ancestors retain newest HEAD semantics', () {
    final refs = CheckpointReferenceCatalog.fromHistory([
      _checkpoint(
        id: 1, parentId: null, operation: 'snapshot',
        head: true, v2: false,
      ),
      _checkpoint(
        id: 2, parentId: 1, operation: 'edit',
        head: true, v2: false,
      ),
    ]);
    expect(refs.first.name, 'HEAD');
    expect(refs.first.checkpointId, 2);
    expect(refs.length, 1);
  });

  test('V2 history with missing or multiple HEAD flags fails closed', () {
    final first = _checkpoint(
      id: 1, parentId: null, operation: 'snapshot',
    );
    final second = _checkpoint(
      id: 2, parentId: 1, operation: 'edit',
    );
    expect(
      () => CheckpointReferenceCatalog.fromHistory([first, second]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    first.isActive = true;
    second.isActive = true;
    expect(
      () => CheckpointReferenceCatalog.fromHistory([first, second]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
  });

  test('reference catalog refuses mixed sessions and broken parent links', () {
    final root = _checkpoint(
      id: 1, parentId: null, operation: 'snapshot', head: true,
    );
    final other = _checkpoint(
      id: 2, parentId: 1, operation: 'edit', sessionId: 2,
    );
    expect(
      () => CheckpointReferenceCatalog.fromHistory([root, other]),
      throwsStateError,
    );
    final missing = _checkpoint(
      id: 3, parentId: 99, operation: 'edit',
    );
    expect(
      () => CheckpointReferenceCatalog.fromHistory([root, missing]),
      throwsStateError,
    );
  });

  test('reference catalog does not include current HEAD as alternate tip', () {
    final refs = CheckpointReferenceCatalog.fromHistory([
      _checkpoint(
        id: 1, parentId: null, operation: 'snapshot',
      ),
      _checkpoint(
        id: 2, parentId: 1, operation: 'edit', head: true,
      ),
    ]);
    expect(refs.map((r) => r.name), ['HEAD']);
  });
}
