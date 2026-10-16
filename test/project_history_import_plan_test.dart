import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';

ProjectSubtitleLineData _line(String text) => ProjectSubtitleLineData.create(
      index: 1,
      startTime: '00:00:01,000',
      endTime: '00:00:01,900',
      original: text,
      edited: null,
      marked: false,
      comment: null,
      resolved: false,
    );

SubtitleLine _modelLine(ProjectSubtitleLineData data) => SubtitleLine()
  ..index = data.index
  ..startTime = data.startTime
  ..endTime = data.endTime
  ..original = data.original
  ..edited = data.edited
  ..marked = data.marked
  ..comment = data.comment
  ..resolved = data.resolved;

ProjectCheckpointData _snapshot({
  required int id,
  int? parent,
  bool isActive = false,
  String? metadata,
  String text = 'Original',
}) =>
    ProjectCheckpointData.create(
      id: id,
      sessionId: 10,
      subtitleCollectionId: 12,
      timestamp: DateTime.utc(2026, 10, 12, 12, 0, id).toIso8601String(),
      operationType: 'snapshot',
      description: 'Checkpoint $id',
      parentCheckpointId: parent,
      isActive: isActive,
      checkpointType: 'snapshot',
      metadata: metadata,
      deltas: const [],
      snapshot: [_line(text)],
    );

void main() {
  test('valid v2 root with a state hash passes import preflight', () {
    final lines = [_modelLine(_line('Original'))];
    final result = PreparedProjectHistory.build([
      _snapshot(
        id: 1,
        isActive: true,
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          stateHash: CheckpointStateHasher.hashLines(lines),
        ),
      ),
    ], toSubtitleLine: _modelLine);
    expect(result.checkpoints.single.id, 1);
    expect(result.checkpoints.single.isActive, isTrue);
  });

  test('tampered v2 snapshot fails without doing any database writes', () {
    final original = [_modelLine(_line('Original'))];
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(
          id: 1,
          text: 'Tampered',
          isActive: true,
          metadata: CheckpointHistoryMetadata.encodePostOperation(
            stateHash: CheckpointStateHasher.hashLines(original),
          ),
        ),
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });

  test('v2 snapshot without hash is rejected instead of treated as trusted',
      () {
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(
          id: 1,
          isActive: true,
          metadata: CheckpointHistoryMetadata.encodePostOperation(),
        ),
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });

  test('v2 graph with multiple heads is rejected', () {
    final hashed = CheckpointHistoryMetadata.encodePostOperation(
      stateHash: CheckpointStateHasher.hashLines([
        _modelLine(_line('Original')),
      ]),
    );
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(id: 1, isActive: true, metadata: hashed),
        _snapshot(id: 2, parent: 1, isActive: true, metadata: hashed),
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });

  test('legacy history with multiple active flags selects one head', () {
    final result = PreparedProjectHistory.build([
      _snapshot(id: 1, isActive: true),
      _snapshot(id: 2, parent: 1, isActive: true),
    ], toSubtitleLine: _modelLine);
    final heads =
        result.checkpoints.where((checkpoint) => checkpoint.isActive).toList();
    expect(heads, hasLength(1));
    expect(heads.single.id, 2);
  });

  test('unsupported history version is not treated as a legacy checkpoint',
      () {
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(
          id: 1,
          isActive: true,
          metadata: '{"_historyVersion":3,"_stateSemantics":"after-operation"}',
        ),
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });

  test('checkpoints from different original sessions are rejected', () {
    final second = ProjectCheckpointData.create(
      id: 2,
      sessionId: 99,
      subtitleCollectionId: 12,
      timestamp: DateTime.utc(2026, 10, 12, 12, 0, 2).toIso8601String(),
      operationType: 'snapshot',
      description: 'Foreign',
      parentCheckpointId: 1,
      isActive: false,
      checkpointType: 'snapshot',
      metadata: null,
      deltas: const [],
      snapshot: [_line('Foreign')],
    );
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(id: 1, isActive: true),
        second,
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });

  test('missing parent is rejected', () {
    expect(
      () => PreparedProjectHistory.build([
        _snapshot(id: 2, parent: 999, isActive: true),
      ], toSubtitleLine: _modelLine),
      throwsA(isA<ProjectHistoryImportException>()),
    );
  });
}
