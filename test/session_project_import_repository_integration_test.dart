import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

import 'support/test_isar_harness.dart';

ProjectSubtitleLineData _line(int index, String text) {
  return ProjectSubtitleLineData.create(
    index: index,
    startTime: '00:00:0$index,000',
    endTime: '00:00:0$index,900',
    original: text,
    edited: null,
    marked: false,
    comment: null,
    resolved: false,
  );
}

void main() {
  late TestIsarHarness harness;
  late SessionProjectImportRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = SessionProjectImportRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  test('typed import remaps exported checkpoint parent ids', () async {
    final first = ProjectCheckpointData.create(
      id: 100,
      sessionId: 7,
      subtitleCollectionId: 11,
      timestamp: DateTime.utc(2026, 10, 3, 12).toIso8601String(),
      operationType: 'snapshot',
      description: 'Initial state',
      parentCheckpointId: null,
      isActive: true,
      checkpointType: 'snapshot',
      metadata: null,
      deltas: const [],
      snapshot: [_line(1, 'One')],
    );

    final second = ProjectCheckpointData.create(
      id: 200,
      sessionId: 7,
      subtitleCollectionId: 11,
      timestamp: DateTime.utc(2026, 10, 3, 13).toIso8601String(),
      operationType: 'edit',
      description: 'Edited line 1',
      parentCheckpointId: 100,
      isActive: true,
      checkpointType: 'delta',
      metadata: null,
      deltas: [
        ProjectDeltaData.create(
          changeType: 'modify',
          lineIndex: 0,
          beforeState: _line(1, 'One'),
          afterState: ProjectSubtitleLineData.create(
            index: 1,
            startTime: '00:00:01,000',
            endTime: '00:00:01,900',
            original: 'One',
            edited: 'Uno',
            marked: false,
            comment: null,
            resolved: false,
          ),
        ),
      ],
      snapshot: const [],
    );

    final document = ProjectDocument.create(
      version: '2.0',
      appVersion: '3.0.0',
      session: ProjectSessionData.create(
        fileName: 'typed.srt',
        lastEditedIndex: 1,
        editMode: true,
        projectFilePath: null,
      ),
      subtitleCollection: ProjectSubtitleCollectionData.create(
        fileName: 'typed.srt',
        filePath: '/original/typed.srt',
        originalFileUri: '/original/typed.srt',
        encoding: 'UTF-8',
        lines: [_line(1, 'One')],
      ),
      checkpoints: [first, second],
      metadata: ProjectMetadataData.create(
        totalLines: 1,
        editedLines: 0,
        markedLines: 0,
        lastSaved: DateTime.utc(2026, 10, 3).toIso8601String(),
      ),
    );

    final session = await repository.importAsNewSession(
      projectDocument: document,
      srtFileInfo: const {'useImportingFile': 'true'},
      originalProjectUri: '/projects/typed.msone',
    );

    final storedCheckpoints = await harness.isar.checkpoints
        .filter()
        .sessionIdEqualTo(session.id)
        .findAll();
    expect(storedCheckpoints, hasLength(2));

    final importedFirst = storedCheckpoints.firstWhere(
      (checkpoint) => checkpoint.description == 'Initial state',
    );
    final importedSecond = storedCheckpoints.firstWhere(
      (checkpoint) => checkpoint.description == 'Edited line 1',
    );

    expect(importedFirst.id, isNot(100));
    expect(importedSecond.id, isNot(200));
    expect(importedSecond.parentCheckpointId, importedFirst.id);
    expect(importedSecond.deltas.single.afterState?.edited, 'Uno');

    final collection =
        await harness.isar.subtitleCollections.get(session.subtitleCollectionId);
    expect(collection, isNotNull);
    expect(collection!.fileName, 'typed.srt');
    expect(collection.lines.single.original, 'One');
  });
}
