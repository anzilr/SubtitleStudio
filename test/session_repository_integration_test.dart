import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/home/repositories/session_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(
  int index,
  String original, {
  String? edited,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = original
    ..edited = edited
    ..marked = false
    ..comment = null
    ..resolved = false;
}

Future<({SubtitleCollection collection, Session session})> _seedSession(
  TestIsarHarness harness, {
  required String fileName,
  required List<SubtitleLine> lines,
  int? lastEditedIndex,
}) async {
  final collection = SubtitleCollection(
    fileName: fileName,
    encoding: 'UTF-8',
    lines: lines,
  );

  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(collection);
  });
  collection.id = collectionId;

  final session = Session(
    fileName: fileName,
    subtitleCollectionId: collectionId,
    lastEditedIndex: lastEditedIndex,
  );

  late int sessionId;
  await harness.isar.writeTxn(() async {
    sessionId = await harness.isar.sessions.put(session);
  });
  session.id = sessionId;

  return (collection: collection, session: session);
}

void main() {
  late TestIsarHarness harness;
  late SessionRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = SessionRepository(harness.isar);
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('SessionRepository persistence', () {
    test('removeSession cascades only the deleted session owned data',
        () async {
      final first = await _seedSession(
        harness,
        fileName: 'first.srt',
        lines: [_line(1, 'First')],
      );
      final second = await _seedSession(
        harness,
        fileName: 'second.srt',
        lines: [_line(1, 'Second')],
      );

      await harness.isar.writeTxn(() async {
        await harness.isar.checkpoints.putAll([
          Checkpoint(
            sessionId: first.session.id,
            subtitleCollectionId: first.collection.id,
            timestamp: DateTime.utc(2026, 10, 3),
            operationType: 'snapshot',
            description: 'First checkpoint',
            deltas: [],
            snapshot: [_line(1, 'First')],
          ),
          Checkpoint(
            sessionId: second.session.id,
            subtitleCollectionId: second.collection.id,
            timestamp: DateTime.utc(2026, 10, 3),
            operationType: 'snapshot',
            description: 'Second checkpoint',
            deltas: [],
            snapshot: [_line(1, 'Second')],
          ),
        ]);

        await harness.isar.videoPreferences.putAll([
          VideoPreferences(
            subtitleCollectionId: first.collection.id,
            videoPath: '/first.mp4',
          ),
          VideoPreferences(
            subtitleCollectionId: second.collection.id,
            videoPath: '/second.mp4',
          ),
        ]);

        await harness.isar.preferences.put(
          Preferences(
            autoSave: true,
            lastEditedSession: first.session.id,
          ),
        );
      });

      await repository.removeSession(first.session);

      expect(await harness.isar.sessions.get(first.session.id), isNull);
      expect(
        await harness.isar.subtitleCollections.get(first.collection.id),
        isNull,
      );
      expect(
        await harness.isar.checkpoints
            .filter()
            .sessionIdEqualTo(first.session.id)
            .findAll(),
        isEmpty,
      );
      expect(
        await harness.isar.videoPreferences
            .filter()
            .subtitleCollectionIdEqualTo(first.collection.id)
            .findAll(),
        isEmpty,
      );
      expect(
        (await harness.isar.preferences.where().findFirst())
            ?.lastEditedSession,
        isNull,
      );

      expect(await harness.isar.sessions.get(second.session.id), isNotNull);
      expect(
        await harness.isar.subtitleCollections.get(second.collection.id),
        isNotNull,
      );
      expect(
        await harness.isar.checkpoints
            .filter()
            .sessionIdEqualTo(second.session.id)
            .findAll(),
        hasLength(1),
      );
      expect(
        await harness.isar.videoPreferences
            .filter()
            .subtitleCollectionIdEqualTo(second.collection.id)
            .findAll(),
        hasLength(1),
      );
    });

    test('fetchSessionSummaries uses persisted collection state', () async {
      final seeded = await _seedSession(
        harness,
        fileName: 'summary.srt',
        lastEditedIndex: 2,
        lines: [
          _line(1, 'Hello'),
          _line(2, 'World', edited: 'Edited'),
        ],
      );

      final summaries =
          await repository.fetchSessionSummaries([seeded.session]);
      final summary = summaries[seeded.session.id];

      expect(summary, isNotNull);
      expect(summary!.totalLines, 2);
      expect(summary.editedLines, 1);
      expect(summary.lastEditedIndex, 2);
      expect(summary.languages, contains('EN'));
    });
  });
}
