import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_loader.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine cue(int number, {String? edited, String original = ''}) =>
    SubtitleLine()
      ..index = number
      ..startTime = '00:00:01,000'
      ..endTime = '00:00:02,450'
      ..original = original
      ..edited = edited
      ..marked = true
      ..comment = 'Note'
      ..resolved = false;

void main() {
  late TestIsarHarness harness;
  late StudioDockSessionLoader loader;

  setUp(() async {
    harness = await TestIsarHarness.open();
    loader = StudioDockSessionLoader(
      ProjectRepository(harness.isar),
      SubtitleRepository(harness.isar, CheckpointRepository(harness.isar)),
    );
  });
  tearDown(() async => harness.close());

  Future<({int session, int collection})> seed({
    required String name,
    required List<SubtitleLine> lines,
  }) async {
    final collection = SubtitleCollection(
      fileName: name,
      encoding: 'UTF-8',
      lines: lines,
    );
    await harness.isar.writeTxn(() async {
      await harness.isar.subtitleCollections.put(collection);
    });
    final session = Session(
      fileName: name,
      subtitleCollectionId: collection.id,
    );
    await harness.isar.writeTxn(() async {
      await harness.isar.sessions.put(session);
    });
    return (session: session.id, collection: collection.id);
  }

  test('read-only snapshot preserves original, nullable edit and empty cues',
      () async {
    final ids = await seed(name: 'Original.srt', lines: [
      cue(1, original: 'One', edited: null),
      cue(2, original: '', edited: ''),
      cue(3, original: 'Three', edited: 'Edited three'),
    ]);
    final data = await loader.load(
      sessionId: ids.session,
      collectionId: ids.collection,
    );
    expect(data.fileName, 'Original.srt');
    expect(data.encoding, 'UTF-8');
    expect(data.cues.map((e) => e.index), [1, 2, 3]);
    expect(data.cues[0].original, 'One');
    expect(data.cues[0].edited, isEmpty);
    expect(data.cues[1].original, isEmpty);
    expect(data.cues[2].edited, 'Edited three');
    expect(data.cues.first.marked, isTrue);
    expect(
      await harness.isar.checkpoints.count(),
      0,
      reason: 'Read-only load must not create history or checkpoints',
    );
    expect((await harness.isar.subtitleCollections.get(ids.collection))!
        .lines.length, 3);
  });

  test('rejects cross-session access to a foreign subtitle collection',
      () async {
    final first = await seed(name: 'One.srt', lines: [cue(1)]);
    final second = await seed(name: 'Two.srt', lines: [cue(1)]);
    await expectLater(
      loader.load(sessionId: first.session, collectionId: second.collection),
      throwsA(isA<StateError>()),
    );
    expect(await harness.isar.checkpoints.count(), 0);
  });

  test('rejects missing session or collection without database mutations',
      () async {
    final ids = await seed(name: 'Any.srt', lines: []);
    await expectLater(
      loader.load(sessionId: 999999, collectionId: ids.collection),
      throwsA(isA<StateError>()),
    );
    await harness.isar.writeTxn(() async {
      await harness.isar.subtitleCollections.delete(ids.collection);
    });
    await expectLater(
      loader.load(sessionId: ids.session, collectionId: ids.collection),
      throwsA(isA<StateError>()),
    );
  });
}
