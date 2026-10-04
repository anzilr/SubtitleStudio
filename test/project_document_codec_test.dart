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
