import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_view.dart';
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

class _DelayedSelectionRepository extends SubtitleRepository {
  _DelayedSelectionRepository(Isar isar, CheckpointRepository checkpoints)
      : super(isar, checkpoints);

  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  final lastWriteFinished = Completer<void>();
  int writeCount = 0;

  @override
  Future<bool> updateLastEditedIndex(int sessionId, int index) async {
    if (++writeCount == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    final saved = await super.updateLastEditedIndex(sessionId, index);
    if (index == 3 && !lastWriteFinished.isCompleted) {
      lastWriteFinished.complete();
    }
    return saved;
  }
}

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
    bool editMode = false,
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
      editMode: editMode,
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
    expect(data.isEditMode, isFalse);
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

  test('loading a scratch project preserves its edit mode', () async {
    final ids = await seed(name: 'Scratch.srt', editMode: true,
        lines: [cue(1, original: '', edited: 'My subtitle')]);
    final data = await loader.load(
      sessionId: ids.session, collectionId: ids.collection);
    expect(data.isEditMode, isTrue);
    expect(data.cues.single.edited, 'My subtitle');
    expect(data.cues.single.original, isEmpty);
  });

  test('desktop loader returns the shared last edited cue for reopen', () async {
    final ids = await seed(name: 'Resume.srt', lines: [
      cue(1, original: 'One'),
      cue(2, original: 'Two'),
      cue(3, original: 'Three'),
    ]);
    final subtitles = SubtitleRepository(
        harness.isar, CheckpointRepository(harness.isar));
    expect(await subtitles.updateLastEditedIndex(ids.session, 3), isTrue);
    final loaded = await loader.load(
        sessionId: ids.session, collectionId: ids.collection);
    expect(loaded.lastEditedIndex, 3);
    final reopened = await loader.load(
        sessionId: ids.session, collectionId: ids.collection);
    expect(reopened.lastEditedIndex, 3);
  });

  test('queued position writes retain the final line after project closure',
      () async {
    final ids = await seed(name: 'ResumeAfterSwitch.srt', lines: [
      cue(1, original: 'One'),
      cue(2, original: 'Two'),
      cue(3, original: 'Three'),
    ]);
    final subtitles = _DelayedSelectionRepository(
        harness.isar, CheckpointRepository(harness.isar));
    final writes = StudioDockSelectionWriteQueue();

    final first = writes.record(
        ids.session, 2, subtitles.updateLastEditedIndex);
    await subtitles.firstWriteStarted.future;
    // The queued final selection must still be written after the first
    // request resumes, even if the UI that enqueued it has closed.
    final last = writes.record(
        ids.session, 3, subtitles.updateLastEditedIndex);
    subtitles.releaseFirstWrite.complete();
    await Future.wait([first, last]);
    await subtitles.lastWriteFinished.future;

    final reopened = await loader.load(
        sessionId: ids.session, collectionId: ids.collection);
    expect(reopened.lastEditedIndex, 3);
    expect(subtitles.writeCount, 2);
  });

  test('an immediate desktop reopen waits for the previous view save',
      () async {
    final ids = await seed(name: 'RapidReopen.srt', lines: [
      cue(1, original: 'One'),
      cue(2, original: 'Two'),
      cue(3, original: 'Three'),
    ]);
    final subtitles = _DelayedSelectionRepository(
        harness.isar, CheckpointRepository(harness.isar));
    // The next editor instance uses the same queue after the old one closes.
    final writes = StudioDockSelectionWriteQueue.shared;
    final first = writes.record(
        ids.session, 2, subtitles.updateLastEditedIndex);
    await subtitles.firstWriteStarted.future;
    final last = writes.record(
        ids.session, 3, subtitles.updateLastEditedIndex);

    var reopened = false;
    final pendingReopen = () async {
      await writes.waitForPending();
      final snapshot = await loader.load(
          sessionId: ids.session, collectionId: ids.collection);
      reopened = true;
      return snapshot;
    }();
    await Future<void>.delayed(Duration.zero);
    expect(reopened, isFalse, reason: 'Do not show an outdated line on reopen');

    subtitles.releaseFirstWrite.complete();
    final snapshot = await pendingReopen;
    await Future.wait([first, last]);
    expect(snapshot.lastEditedIndex, 3);
    expect(subtitles.writeCount, 2);
  });

  test('loader exposes the already-read collection for desktop settings',
      () async {
    final ids = await seed(name: 'Settings.srt', lines: [
      cue(1, original: 'Hello', edited: 'Edited'),
    ]);
    SubtitleCollection? cached;
    await loader.load(
      sessionId: ids.session,
      collectionId: ids.collection,
      onCollectionLoaded: (value) => cached = value,
    );
    expect(cached?.id, ids.collection);
    expect(cached?.lines.single.edited, 'Edited');
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
