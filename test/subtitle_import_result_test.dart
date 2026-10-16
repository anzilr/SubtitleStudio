import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/models/subtitle_import_result.dart';

void main() {
  test('SubtitleImportResult converts legacy persistence data', () {
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

    final result = SubtitleImportResult.fromLegacyMap({
      'subtitleCollectionId': 9,
      'fileName': 'movie.srt',
      'lastEditedIndex': 4,
      'sessionId': 12,
      'editMode': true,
      'session': session,
      'subtitleCollection': collection,
    });

    expect(result.subtitleCollectionId, 9);
    expect(result.sessionId, 12);
    expect(result.lastEditedIndex, 4);
    expect(result.editMode, isTrue);
    expect(identical(result.session, session), isTrue);
    expect(identical(result.subtitleCollection, collection), isTrue);
  });

  test('SubtitleImportResult rejects incomplete persistence data', () {
    expect(
      () => SubtitleImportResult.fromLegacyMap({
        'subtitleCollectionId': 9,
        'sessionId': 12,
      }),
      throwsStateError,
    );
  });
}
