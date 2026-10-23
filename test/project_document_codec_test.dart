import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

void main() {
  group('ProjectDocumentCodec', () {
    test('decodes current project shape', () {
      final document = ProjectDocumentCodec.decode(
        '''
        {
          "version": "2.0",
          "createdAt": "2026-09-28T00:00:00.000Z",
          "appVersion": "3.0.0",
          "session": {
            "fileName": "movie.srt",
            "lastEditedIndex": 5,
            "editMode": true
          },
          "subtitleCollection": {
            "fileName": "movie.srt",
            "encoding": "UTF-8",
            "originalFileUri": "content://subtitle",
            "lines": [
              {
                "index": 1,
                "startTime": "00:00:01,000",
                "endTime": "00:00:02,000",
                "original": "Hello"
              }
            ]
          },
          "checkpoints": [],
          "metadata": {"totalLines": 1}
        }
        ''',
      );

      expect(document.version, '2.0');
      expect(document.session.fileName, 'movie.srt');
      expect(document.totalLines, 1);
      expect(document.originalFileUri, 'content://subtitle');
      expect(document.subtitleCollection.lines.single.original, 'Hello');
      expect(document.checkpoints, isEmpty);
    });

    test('rejects malformed JSON', () {
      expect(
        () => ProjectDocumentCodec.decode('{not-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing required sections', () {
      expect(
        () => ProjectDocumentCodec.decode(
          '{"version":"2.0","session":{},"subtitleCollection":null}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-list subtitle lines', () {
      expect(
        () => ProjectDocumentCodec.decode(
          '''
          {
            "version":"2.0",
            "session":{},
            "subtitleCollection":{"lines":{}}
          }
          ''',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('versioned .msone refs survive codec round-trip', () {
      final references = ProjectHistoryReferencesData.create(entries: const [
        ProjectHistoryReferenceData(
          name: 'HEAD', kind: 'head', targetCheckpointId: 42,
        ),
        ProjectHistoryReferenceData(
          name: 'refs/heads/main', kind: 'branch', targetCheckpointId: 42,
        ),
        ProjectHistoryReferenceData(
          name: 'refs/bookmarks/manual-35',
          kind: 'bookmark', targetCheckpointId: 35,
        ),
      ]);
      final encoded = references.toJson();
      final restored = ProjectHistoryReferencesData.fromJson(encoded);
      expect(restored.schemaVersion, 1);
      expect(restored.entries.map((ref) => ref.name),
          ['HEAD', 'refs/heads/main', 'refs/bookmarks/manual-35']);
      expect(restored.entries.last.targetCheckpointId, 35);
      expect(() => restored.entries.clear(), throwsUnsupportedError);
    });

    test('rejects malformed history references and unsupported versions', () {
      final validHead = {
        'name': 'HEAD', 'kind': 'head', 'targetCheckpointId': 5,
      };
      for (final entry in [
        {'name': '../escape', 'kind': 'branch', 'targetCheckpointId': 5},
        {'name': 'refs/heads/../test', 'kind': 'branch', 'targetCheckpointId': 5},
        {'name': 'refs/heads/main', 'kind': 'bookmark', 'targetCheckpointId': 5},
        {'name': 'refs/heads/main', 'kind': 'branch', 'targetCheckpointId': -1},
        {'name': 'refs/heads/e.lock', 'kind': 'branch', 'targetCheckpointId': 5},
        {'name': 'refs/heads/test', 'kind': 'other', 'targetCheckpointId': 5},
      ]) {
        expect(
          () => ProjectHistoryReferencesData.fromJson({
            'schemaVersion': 1, 'entries': [validHead, entry],
          }),
          throwsFormatException,
        );
      }
      for (final refs in [
        {'schemaVersion': 2, 'entries': [validHead]},
        {'schemaVersion': 1, 'entries': [validHead, validHead]},
        {'schemaVersion': 1, 'entries': [
          {'name': 'refs/heads/main', 'kind': 'branch', 'targetCheckpointId': 5},
        ]},
      ]) {
        expect(
          () => ProjectHistoryReferencesData.fromJson(refs),
          throwsFormatException,
        );
      }
    });

    test('older .msone archives leave the new optional section absent', () {
      final old = ProjectDocumentCodec.decode(
        '{"version":"1.0","session":{},'
        '"subtitleCollection":{"lines":[]},"checkpoints":[]}',
      );
      expect(old.historyReferences, isNull);
      expect(old.toJson().containsKey('historyRefs'), isFalse);
    });

    test('allows projects without checkpoints for compatibility', () {
      final document = ProjectDocumentCodec.decode(
        '''
        {
          "version":"1.0",
          "session":{},
          "subtitleCollection":{"lines":[]}
        }
        ''',
      );

      expect(document.version, '1.0');
      expect(document.checkpoints, isEmpty);
    });
  });
}
