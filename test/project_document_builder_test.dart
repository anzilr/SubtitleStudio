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
      );

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
      expect(document.session['projectFilePath'], 'content://project.msone');

      final line =
          (document.subtitleCollection['lines'] as List).single as Map;
      expect(line['edited'], 'After');
      expect(line['marked'], isTrue);
      expect(line['comment'], 'Check wording');
      expect(line['resolved'], isTrue);

      final exportedCheckpoint = document.checkpoints.single as Map;
      expect(exportedCheckpoint['checkpointType'], 'delta');
      expect(exportedCheckpoint['metadata'], '{"source":"test"}');

      final exportedDelta =
          (exportedCheckpoint['deltas'] as List).single as Map;
      expect((exportedDelta['beforeState'] as Map)['original'], 'Before');
      expect((exportedDelta['afterState'] as Map)['edited'], 'After');

      final exportedSnapshot =
          (exportedCheckpoint['snapshot'] as List).single as Map;
      expect(exportedSnapshot['original'], 'Before');
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

      final metadata = data['metadata'] as Map<String, dynamic>;
      expect(metadata['totalLines'], 3);
      expect(metadata['editedLines'], 1);
      expect(metadata['markedLines'], 1);
      expect(metadata['lastSaved'], '2026-09-28T00:00:00.000Z');
    });
  });
}
