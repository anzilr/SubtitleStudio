import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_import.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';

ProjectDocument _document(String linesJson) {
  return ProjectDocumentCodec.decode(
    '''
    {
      "version":"2.0",
      "session":{},
      "subtitleCollection":{
        "lines":$linesJson
      }
    }
    ''',
  );
}

void main() {
  group('ProjectCommentImportPlan', () {
    test('extracts comments with mark and resolved state', () {
      final plan = ProjectCommentImportPlan.fromDocument(
        _document(
          '''
          [
            {
              "index":1,
              "comment":"Check timing",
              "marked":true,
              "resolved":false
            },
            {
              "index":2,
              "comment":"Done",
              "marked":false,
              "resolved":true
            }
          ]
          ''',
        ),
      );

      expect(plan.count, 2);
      expect(plan.entries[0].index, 1);
      expect(plan.entries[0].comment, 'Check timing');
      expect(plan.entries[0].marked, isTrue);
      expect(plan.entries[0].resolved, isFalse);
      expect(plan.entries[1].resolved, isTrue);
    });

    test('preserves unicode comments exactly', () {
      const comment = 'മലയാളം تعليق 日本語';
      final plan = ProjectCommentImportPlan.fromDocument(
        _document(
          '''
          [
            {
              "index":4,
              "comment":"$comment",
              "marked":true,
              "resolved":true
            }
          ]
          ''',
        ),
      );

      expect(plan.entries.single.comment, comment);
    });

    test('ignores missing, empty, or invalid comments', () {
      final plan = ProjectCommentImportPlan.fromDocument(
        _document(
          '''
          [
            {"index":1,"comment":""},
            {"index":2,"comment":"   "},
            {"index":3},
            {"comment":"No index"},
            {"index":"4","comment":"Wrong index type"},
            {"index":5,"comment":"Keep me"}
          ]
          ''',
        ),
      );

      expect(plan.count, 1);
      expect(plan.entries.single.index, 5);
    });

    test('defaults missing mark and resolved flags to false', () {
      final plan = ProjectCommentImportPlan.fromDocument(
        _document('[{"index":1,"comment":"Note"}]'),
      );

      expect(plan.entries.single.marked, isFalse);
      expect(plan.entries.single.resolved, isFalse);
    });
  });
}
