import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_builder.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  bool marked = false,
  String? comment,
  bool resolved = false,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = edited
    ..marked = marked
    ..comment = comment
    ..resolved = resolved;
}

void main() {
  group('ProjectDocumentBuilder', () {
    test('preserves subtitle metadata and checkpoint state', () {
      final before = _line(index: 1, original: 'Before');
      final after = _line(
        index: 1,
        original: 'Before',
        edited: 'After',
        marked: true,
        comment: 'Check wording',
        resolved: true,
      );

      final delta = SubtitleLineDelta()
        ..changeType = 'modify'
        ..lineIndex = 0
        ..beforeState = before
        ..afterState = after;

      final checkpoint = Checkpoint(
        sessionId: 7,
        subtitleCollectionId: 11,
        timestamp: DateTime.utc(2026, 9, 28, 12),
        operationType: 'edit',
        description: 'Edited line 1',
        deltas: [delta],
        snapshot: [before],
        checkpointType: 'delta',
        metadata: '{"source":"test"}',
      )..id = 42;

      final session = Session(
        fileName: 'movie.srt',
        subtitleCollectionId: 11,
        lastEditedIndex: 1,
        editMode: true,
        projectFilePath: 'content://project.msone',
      );

      final collection = SubtitleCollection(
        fileName: 'movie.srt',
        filePath: '/tmp/movie.srt',
        originalFileUri: 'content://movie.srt',
        encoding: 'UTF-8',
        lines: [after],
      );

      final data = ProjectDocumentBuilder.build(
        session: session,
        subtitleCollection: collection,
        checkpoints: [checkpoint],
        projectVersion: '2.0',
        appVersion: '3.0.0',
        now: DateTime.utc(2026, 9, 28, 13),
      );

      final document = ProjectDocumentCodec.decode(
        ProjectDocumentCodec.encode(data),
      );

      expect(document.version, '2.0');
      expect(document.totalLines, 1);
      expect(
        document.session.projectFilePath,
        'content://project.msone',
      );

      final line = document.subtitleCollection.lines.single;
      expect(line.edited, 'After');
      expect(line.marked, isTrue);
      expect(line.comment, 'Check wording');
      expect(line.resolved, isTrue);

      expect(document.historyReferences, isNotNull);
      expect(document.historyReferences!.schemaVersion, 1);
      expect(
        document.historyReferences!.entries
            .map((ref) => (ref.name, ref.kind, ref.targetCheckpointId))
            .toList(),
        [
          ('HEAD', 'head', 42),
          ('refs/heads/main', 'branch', 42),
        ],
      );
      final exportedCheckpoint = document.checkpoints.single;
      expect(exportedCheckpoint.id, 42);
      expect(exportedCheckpoint.checkpointType, 'delta');
      expect(exportedCheckpoint.metadata, '{"source":"test"}');

      final exportedDelta = exportedCheckpoint.deltas.single;
      expect(exportedDelta.beforeState?.original, 'Before');
      expect(exportedDelta.afterState?.edited, 'After');

      final exportedSnapshot = exportedCheckpoint.snapshot.single;
      expect(exportedSnapshot.original, 'Before');
    });

    test('persists named branches, bookmarks, and detached HEAD in .msone',
        () {
      final session = Session(
        fileName: 'archived.srt', subtitleCollectionId: 15,
      )..id = 8;
      final collection = SubtitleCollection(
        fileName: 'archived.srt',
        encoding: 'UTF-8',
        lines: [_line(index: 1, original: 'Text')],
      )..id = 15;
      final checkpoint = Checkpoint(
        sessionId: 8,
        subtitleCollectionId: 15,
        timestamp: DateTime.utc(2026, 10, 13),
        operationType: 'snapshot',
        description: 'Initial',
        isActive: true,
        checkpointType: 'snapshot',
        deltas: const [],
        snapshot: [_line(index: 1, original: 'Text')],
      )..id = 30;
      final now = DateTime.utc(2026, 10, 13);
      HistoryRef makeRef(String name, String kind, {String? attached}) =>
          HistoryRef(
            sessionId: 8, subtitleCollectionId: 15,
            name: name, kind: kind, targetCheckpointId: 30,
            symbolicBranchName: attached,
            createdAt: now, updatedAt: now,
          );
      final refs = [
        makeRef('HEAD', 'head'),
        makeRef('refs/heads/main', 'branch'),
        makeRef('refs/heads/custom-review', 'branch'),
        makeRef('refs/bookmarks/approved', 'bookmark'),
      ];
      final document = ProjectDocumentBuilder.build(
        session: session,
        subtitleCollection: collection,
        checkpoints: [checkpoint],
        persistentReferences: refs,
        projectVersion: '2.0',
        appVersion: '3.0.0',
      );
      final restored = ProjectDocumentCodec.decode(
        ProjectDocumentCodec.encode(document),
      );
      expect(restored.historyReferences!.entries.map((r) => r.name).toSet(), {
        'HEAD', 'refs/heads/main', 'refs/heads/custom-review',
        'refs/bookmarks/approved',
      });
      final head = restored.historyReferences!.entries
          .firstWhere((r) => r.name == 'HEAD');
      expect(head.attachmentSpecified, isTrue);
      expect(head.symbolicBranchName, isNull);
      expect(restored.checkpoints.single.id, 30);
    });

    test('derives stable metadata from the collection', () {
      final collection = SubtitleCollection(
        fileName: 'sample.srt',
        encoding: 'UTF-8',
        lines: [
          _line(index: 1, original: 'One', edited: 'Uno', marked: true),
          _line(index: 2, original: 'Two'),
          _line(index: 3, original: 'Three', edited: ''),
        ],
      );

      final data = ProjectDocumentBuilder.build(
        session: Session(fileName: 'sample.srt', subtitleCollectionId: 4),
        subtitleCollection: collection,
        checkpoints: const [],
        projectVersion: '2.0',
        appVersion: '3.0.0',
        now: DateTime.utc(2026, 9, 28),
      );

      expect(data.metadata.totalLines, 3);
      expect(data.metadata.editedLines, 1);
      expect(data.metadata.markedLines, 1);
      expect(data.metadata.lastSaved, '2026-09-28T00:00:00.000Z');
    });
  });
}
