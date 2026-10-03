import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line({
  required int index,
  required String original,
  String? edited,
  required String start,
  required String end,
}) {
  return SubtitleLine()
    ..index = index
    ..startTime = start
    ..endTime = end
    ..original = original
    ..edited = edited
    ..marked = false
    ..comment = null
    ..resolved = false;
}

Future<({int collectionId, int sessionId})> _seed(
  TestIsarHarness harness,
) async {
  final collection = SubtitleCollection(
    fileName: 'edit-line.srt',
    encoding: 'UTF-8',
    lines: [
      _line(
        index: 1,
        original: 'One',
        start: '00:00:01,000',
        end: '00:00:01,900',
      ),
      _line(
        index: 2,
        original: 'Two',
        start: '00:00:02,000',
        end: '00:00:02,900',
      ),
    ],
  );

  late int collectionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(collection);
  });

  final session = Session(
    fileName: 'edit-line.srt',
    subtitleCollectionId: collectionId,
  );

  late int sessionId;
  await harness.isar.writeTxn(() async {
    sessionId = await harness.isar.sessions.put(session);
  });

  return (collectionId: collectionId, sessionId: sessionId);
}

void main() {
  late TestIsarHarness harness;
  late EditLineRepository repository;
  bool harnessOpened = false;

  setUp(() async {
    harness = await TestIsarHarness.open();
    harnessOpened = true;
    repository = EditLineRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
      CheckpointRepository(harness.isar),
    );
  });

  tearDown(() async {
    if (harnessOpened) {
      await harness.close();
      harnessOpened = false;
    }
  });

  group('EditLineRepository persistence', () {
    test('save stores edit and snapshots the true pre-edit state', () async {
      final ids = await _seed(harness);
      await harness.isar.writeTxn(() async {
        await harness.isar.preferences.put(
          Preferences(
            autoSave: true,
            checkpointStrategy: 'snapshot',
          ),
        );
      });

      final before =
          await repository.fetchSubtitleLine(ids.collectionId, 1);
      expect(before, isNotNull);

      final updated = _line(
        index: 1,
        original: 'One',
        edited: 'Translated one',
        start: '00:00:01,000',
        end: '00:00:01,900',
      );

      expect(
        await repository.saveSubtitleLineChanges(
          collectionId: ids.collectionId,
          updatedLine: updated,
          sessionId: ids.sessionId,
          beforeLine: before,
        ),
        isTrue,
      );

      final stored =
          await repository.fetchSubtitleLine(ids.collectionId, 1);
      expect(stored?.edited, 'Translated one');

      final checkpoints = await harness.isar.checkpoints
          .filter()
          .sessionIdEqualTo(ids.sessionId)
          .findAll();
      expect(checkpoints, hasLength(1));

      final checkpoint = checkpoints.single;
      expect(checkpoint.checkpointType, 'snapshot');
      expect(checkpoint.snapshot, hasLength(2));
      expect(checkpoint.snapshot.first.original, 'One');
      expect(checkpoint.snapshot.first.edited, isNull);
      expect(checkpoint.deltas, hasLength(1));
      expect(checkpoint.deltas.single.beforeState?.edited, isNull);
      expect(
        checkpoint.deltas.single.afterState?.edited,
        'Translated one',
      );
    });

    test('add and delete persist normalized cue indexes', () async {
      final ids = await _seed(harness);

      expect(
        await repository.addSubtitleLine(
          ids.collectionId,
          _line(
            index: 2,
            original: 'Between',
            start: '00:00:01,950',
            end: '00:00:01,990',
          ),
          1,
        ),
        isTrue,
      );

      var collection =
          await repository.fetchSubtitleCollection(ids.collectionId);
      expect(
        collection!.lines.map((line) => line.original).toList(),
        ['One', 'Between', 'Two'],
      );
      expect(
        collection.lines.map((line) => line.index).toList(),
        [1, 2, 3],
      );

      expect(
        await repository.deleteSubtitleLine(ids.collectionId, 1),
        isTrue,
      );

      collection =
          await repository.fetchSubtitleCollection(ids.collectionId);
      expect(
        collection!.lines.map((line) => line.original).toList(),
        ['One', 'Two'],
      );
      expect(
        collection.lines.map((line) => line.index).toList(),
        [1, 2],
      );
    });
  });
}
