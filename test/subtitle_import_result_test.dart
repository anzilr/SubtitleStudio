import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/models/subtitle_import_result.dart';

void main() {
  test('SubtitleImportResult retains typed import persistence state', () {
    final collection = SubtitleCollection(
      fileName: 'movie.srt',
      encoding: 'UTF-8',
      lines: const [],
    );
    final session = Session(
      fileName: 'movie.srt',
      subtitleCollectionId: 9,
      editMode: true,
    );

    final result = SubtitleImportResult(
      subtitleCollectionId: 9,
      fileName: 'movie.srt',
      lastEditedIndex: 4,
      sessionId: 12,
      editMode: true,
      session: session,
      subtitleCollection: collection,
    );

    expect(result.subtitleCollectionId, 9);
    expect(result.fileName, 'movie.srt');
    expect(result.sessionId, 12);
    expect(result.lastEditedIndex, 4);
    expect(result.editMode, isTrue);
    expect(identical(result.session, session), isTrue);
    expect(identical(result.subtitleCollection, collection), isTrue);
  });

  test('SubtitleImportResult allows a new session without an edit position', () {
    final collection = SubtitleCollection(
      fileName: 'new.srt',
      encoding: 'UTF-8',
      lines: const [],
    );
    final session = Session(
      fileName: 'new.srt',
      subtitleCollectionId: 18,
      editMode: false,
    );

    final result = SubtitleImportResult(
      subtitleCollectionId: 18,
      fileName: 'new.srt',
      lastEditedIndex: null,
      sessionId: 24,
      editMode: false,
      session: session,
      subtitleCollection: collection,
    );

    expect(result.lastEditedIndex, isNull);
    expect(result.editMode, isFalse);
    expect(identical(result.session, session), isTrue);
    expect(identical(result.subtitleCollection, collection), isTrue);
  });
}
