import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_reference_catalog.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';

Checkpoint _checkpoint(
  int id, {
  int? parent,
  bool active = false,
  bool v2 = false,
  String operation = 'edit',
  int sessionId = 6,
  int collectionId = 9,
  int? timestampMinute,
}) => Checkpoint(
  sessionId: sessionId,
  subtitleCollectionId: collectionId,
  timestamp: DateTime.utc(2026, 10, 12)
      .add(Duration(minutes: timestampMinute ?? id)),
  operationType: operation,
  description: 'Checkpoint $id',
  parentCheckpointId: parent,
  isActive: active,
  checkpointType: 'snapshot',
  deltas: const <SubtitleLineDelta>[],
  snapshot: const <SubtitleLine>[],
  metadata: v2 ? CheckpointHistoryMetadata.encodePostOperation() : null,
)..id = id;

void main() {
  test('empty history needs no refs or normalized HEAD', () {
    final plan = CheckpointReferenceMigrationPlan.prepare([]);
    expect(plan.references, isEmpty);
    expect(plan.headCheckpointId, isNull);
    expect(plan.requiresLegacyHeadNormalization, isFalse);
  });

  test('legacy active ancestor flags select latest and request normalization',
      () {
    final old = [
      _checkpoint(1, active: true, operation: 'snapshot'),
      _checkpoint(2, parent: 1, active: true),
      _checkpoint(3, parent: 2),
    ];
    final plan = CheckpointReferenceMigrationPlan.prepare(old);
    expect(plan.headCheckpointId, 2);
    expect(plan.requiresLegacyHeadNormalization, isTrue);
    expect(plan.references.map((ref) => (ref.name, ref.checkpointId)).toList(),
      [
        ('HEAD', 2),
        ('refs/heads/main', 2),
        ('refs/heads/alternate-3', 3),
      ],
    );
    // Dry-run must not mutate persisted flags before the migration txn.
    expect(old.map((c) => c.isActive).toList(), [true, true, false]);
  });

  test('headless legacy history chooses deterministic newest timestamp and ID',
      () {
    final plan = CheckpointReferenceMigrationPlan.prepare([
      _checkpoint(1, operation: 'snapshot', timestampMinute: 5),
      _checkpoint(2, parent: 1, timestampMinute: 8),
      _checkpoint(3, parent: 1, timestampMinute: 8),
    ]);
    expect(plan.headCheckpointId, 3);
    expect(plan.requiresLegacyHeadNormalization, isTrue);
    expect(plan.references.where((r) =>
      r.kind == CheckpointReferenceKind.branchTip)
      .map((r) => r.name).toList(),
      ['refs/heads/main', 'refs/heads/alternate-2'],
    );
  });

  test('V2 history plans main ref, other branch tips and manual bookmarks',
      () {
    final plan = CheckpointReferenceMigrationPlan.prepare([
      _checkpoint(1, v2: true, operation: 'snapshot'),
      _checkpoint(2, parent: 1, v2: true),
      _checkpoint(3, parent: 2, v2: true),
      _checkpoint(4, parent: 2, v2: true, operation: 'manual'),
      _checkpoint(5, parent: 4, v2: true, active: true),
    ]);
    expect(plan.requiresLegacyHeadNormalization, isFalse);
    expect(plan.references.map((r) => r.name).toList(), [
      'HEAD',
      'refs/heads/main',
      'refs/heads/alternate-3',
      'refs/bookmarks/manual-4',
    ]);
  });

  test('plan is independent of input order and preserves read-only refs',
      () {
    final records = [
      _checkpoint(1, v2: true, operation: 'snapshot'),
      _checkpoint(2, parent: 1, v2: true, active: true),
      _checkpoint(3, parent: 1, v2: true, operation: 'manual'),
    ];
    final a = CheckpointReferenceMigrationPlan.prepare(records);
    final b = CheckpointReferenceMigrationPlan.prepare(records.reversed.toList());
    expect(a.references.map((r) => (r.name, r.checkpointId)),
        b.references.map((r) => (r.name, r.checkpointId)));
    expect(() => a.references.clear(), throwsUnsupportedError);
    expect(() => a.sourceCheckpointIds.clear(), throwsUnsupportedError);
  });

  test('bad graphs fail before proposing any ref migration', () {
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, v2: true, active: true),
        _checkpoint(2, v2: true, active: true, parent: 1),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, v2: true),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, active: true),
        _checkpoint(1),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, active: true),
        _checkpoint(2, parent: 99),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, parent: 2, active: true),
        _checkpoint(2, parent: 1),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, active: true),
        _checkpoint(2, parent: 1, sessionId: 7),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
    expect(
      () => CheckpointReferenceMigrationPlan.prepare([
        _checkpoint(1, active: true),
        _checkpoint(2, parent: 1, collectionId: 8),
      ]),
      throwsA(isA<CheckpointIntegrityException>()),
    );
  });

  test('import remaps every ref target without changing user-facing names',
      () {
    final plan = CheckpointReferenceMigrationPlan.prepare([
      _checkpoint(1, v2: true, operation: 'snapshot'),
      _checkpoint(2, parent: 1, v2: true),
      _checkpoint(3, parent: 2, v2: true, active: true),
      _checkpoint(4, parent: 2, v2: true, operation: 'manual'),
    ]);
    final mapped = plan.remap(
      destinationSessionId: 55,
      destinationCollectionId: 77,
      idMap: {1: 301, 2: 302, 3: 303, 4: 304},
    );
    expect(mapped.sessionId, 55);
    expect(mapped.subtitleCollectionId, 77);
    expect(mapped.headCheckpointId, 303);
    expect(mapped.references.map((r) => (r.name, r.checkpointId)).toList(), [
      ('HEAD', 303),
      ('refs/heads/main', 303),
      ('refs/heads/alternate-4', 304),
      ('refs/bookmarks/manual-4', 304),
    ]);
    expect(plan.headCheckpointId, 3);
    expect(mapped.sourceCheckpointIds, {301, 302, 303, 304});
  });

  test('incomplete, colliding or invalid import mappings fail closed', () {
    final plan = CheckpointReferenceMigrationPlan.prepare([
      _checkpoint(1, active: true),
      _checkpoint(2, parent: 1),
    ]);
    for (final mapping in [
      {1: 100},
      {1: 100, 2: 100},
      {1: 0, 2: 102},
      {1: 101, 3: 103},
      {1: 101, 2: 102, 3: 103},
    ]) {
      expect(() => plan.remap(
        destinationSessionId: 10,
        destinationCollectionId: 11,
        idMap: mapping,
      ), throwsA(isA<CheckpointIntegrityException>()));
    }
  });
}
