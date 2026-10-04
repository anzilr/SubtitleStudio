import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String text) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  late TestIsarHarness harness;
  late SubtitleImportRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = SubtitleImportRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('SubtitleImportRepository', () {
    test('persists collection and linked session metadata', () async {
      final result = await repository.storeSubtitleData(
        lines: [_line(1, 'One'), _line(2, 'Two')],
        fileName: 'import.srt',
        encoding: 'UTF-8',
        filePath: '/storage/import.srt',
        originalFileUri: 'content://subtitle/import',
        projectFilePath: '/projects/import.msone',
        macOsSrtBookmark: 'bookmark-data',
        editMode: true,
      );

      final collection =
          await harness.isar.subtitleCollections.get(result.subtitleCollectionId);
      final session = await harness.isar.sessions.get(result.sessionId);

      expect(collection, isNotNull);
      expect(collection!.fileName, 'import.srt');
      expect(collection.encoding, 'UTF-8');
      expect(collection.filePath, '/storage/import.srt');
      expect(collection.originalFileUri, 'content://subtitle/import');
      expect(collection.macOsSrtBookmark, 'bookmark-data');
      expect(collection.lines.map((line) => line.original).toList(), [
        'One',
        'Two',
      ]);

      expect(session, isNotNull);
      expect(session!.subtitleCollectionId, collection.id);
      expect(session.fileName, 'import.srt');
      expect(session.editMode, isTrue);
      expect(session.projectFilePath, '/projects/import.msone');

      expect(result.subtitleCollection.id, collection.id);
      expect(result.session.id, session.id);
    });

    test('last edited session update reuses the existing preferences row',
        () async {
      await harness.isar.writeTxn(() async {
        await harness.isar.preferences.put(
          Preferences(
            autoSave: false,
            themeMode: 'dark',
          ),
        );
      });

      await repository.updateLastEditedSession(42);
      await repository.updateLastEditedSession(84);

      final preferences = await harness.isar.preferences.where().findAll();
      expect(preferences, hasLength(1));
      expect(preferences.single.lastEditedSession, 84);
      expect(preferences.single.themeMode, 'dark');
      expect(preferences.single.autoSave, isFalse);
    });

    test('invalid last edited session id does not create preferences', () async {
      await repository.updateLastEditedSession(0);
      expect(await harness.isar.preferences.where().findAll(), isEmpty);
    });
  });
}
