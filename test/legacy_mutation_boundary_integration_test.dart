import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/repositories/waveform_subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_preferences_repository.dart';
import 'package:subtitle_studio/screens/edit_line/repositories/edit_line_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';

import 'support/test_isar_harness.dart';

SubtitleLine _line(int index, String text) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:0$index,000'
  ..endTime = '00:00:0$index,800'
  ..original = text
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

Future<({int collectionId, int sessionId})> _seed(
  TestIsarHarness harness,
) async {
  late int collectionId;
  late int sessionId;
  await harness.isar.writeTxn(() async {
    collectionId = await harness.isar.subtitleCollections.put(
      SubtitleCollection(
        fileName: 'legacy-guard.srt',
        encoding: 'UTF-8',
        lines: [_line(1, 'One'), _line(2, 'Two')],
      ),
    );
    sessionId = await harness.isar.sessions.put(
      Session(
        fileName: 'legacy-guard.srt',
        subtitleCollectionId: collectionId,
      ),
    );
  });
  return (collectionId: collectionId, sessionId: sessionId);
}

void main() {
  late TestIsarHarness harness;
  late SubtitleRepository editor;
  late EditLineRepository editLine;
  late WaveformSubtitleRepository waveform;
  late CheckpointRepository history;

  setUp(() async {
    harness = await TestIsarHarness.open();
    history = CheckpointRepository(harness.isar);
    editor = SubtitleRepository(harness.isar, history);
    editLine = EditLineRepository(
      harness.isar,
      EditLinePreferencesRepository(harness.isar),
    );
    waveform = WaveformSubtitleRepository(harness.isar);
  });

  tearDown(() async => harness.close());

  test('V2 history rejects all sessionless Editor line mutations', () async {
    final ids = await _seed(harness);
    final root = await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    final first = _line(1, 'Mutated');
    final second = _line(2, 'Extra');

    expect(await editor.updateMultipleLines(
      ids.collectionId, [first],
    ), isFalse);
    expect(await editor.markLine(ids.collectionId, 0, true), isFalse);
    expect(await editor.updateComment(ids.collectionId, 0, 'Old edit'), isFalse);
    expect(await editor.updateResolved(ids.collectionId, 0, true), isFalse);
    expect(await editor.unmarkLine(ids.collectionId, 0), isFalse);
    expect(await editor.deleteLine(ids.collectionId, 0), isFalse);
    expect(await editor.addLine(ids.collectionId, second, 1), isFalse);
    expect(await editor.splitLine(ids.collectionId, first, second, 0), isFalse);
    expect(await editor.mergeLines(ids.collectionId, first, 0, 1), isFalse);

    final current =
        (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(current.lines.map((l) => l.original).toList(), ['One', 'Two']);
    expect(current.lines.first.comment, isNull);
    expect(current.lines.first.marked, isFalse);
    expect((await history.getHeadCheckpoint(ids.sessionId))!.id, root);
    expect((await history.validateHistory(ids.sessionId)).isHealthy, isTrue);
  });

  test('V2 history rejects all sessionless Edit Line mutations', () async {
    final ids = await _seed(harness);
    final root = await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    final inserted = _line(3, 'New');

    expect(await editLine.updateSubtitleLine(
      collectionId: ids.collectionId,
      lineIndex: 1,
      originalText: 'Overwrite',
      editedText: 'Overwrite',
      startTime: '00:00:01,000',
      endTime: '00:00:01,800',
    ), isFalse);
    expect(await editLine.addSubtitleLine(
      ids.collectionId, inserted, 1,
    ), isFalse);
    expect(await editLine.deleteSubtitleLine(
      ids.collectionId, 0,
    ), isFalse);
    expect(await editLine.markSubtitleLine(
      ids.collectionId, 0, true,
    ), isFalse);
    expect(await editLine.updateSubtitleLineComment(
      ids.collectionId, 0, 'Overwrite',
    ), isFalse);
    expect(await editLine.updateSubtitleLineResolved(
      ids.collectionId, 0, true,
    ), isFalse);

    final current =
        (await editLine.fetchSubtitleCollection(ids.collectionId))!;
    expect(current.lines.map((l) => l.original).toList(), ['One', 'Two']);
    expect(current.lines.first.comment, isNull);
    expect(current.lines.first.marked, isFalse);
    expect((await history.getHeadCheckpoint(ids.sessionId))!.id, root);
  });

  test('sessionless waveform timing cannot bypass V2 history', () async {
    final ids = await _seed(harness);
    await history.createInitialSnapshot(
      sessionId: ids.sessionId,
      subtitleCollectionId: ids.collectionId,
    );
    final newer = _line(1, 'One')
      ..startTime = '00:00:08,000'
      ..endTime = '00:00:09,000';
    expect(await waveform.updateLines(ids.collectionId, [newer]), isFalse);
    expect(
      (await editor.fetchSubtitleCollection(ids.collectionId))!
          .lines.first.startTime,
      '00:00:01,000',
    );
  });

  test('legacy-only collections retain compatible raw line mutations',
      () async {
    final ids = await _seed(harness);
    expect(await editor.markLine(ids.collectionId, 0, true), isTrue);
    expect(await editLine.updateSubtitleLineComment(
      ids.collectionId, 0, 'Legacy comment',
    ), isTrue);
    expect(await editLine.updateSubtitleLine(
      collectionId: ids.collectionId,
      lineIndex: 1,
      originalText: 'Legacy text',
      editedText: 'Translation',
      startTime: '00:00:01,000',
      endTime: '00:00:01,800',
    ), isTrue);

    final current =
        (await editor.fetchSubtitleCollection(ids.collectionId))!;
    expect(current.lines.first.original, 'Legacy text');
    expect(current.lines.first.edited, 'Translation');
    expect(current.lines.first.marked, isTrue);
    expect(current.lines.first.comment, 'Legacy comment');
    expect(await history.getCheckpointsForSession(ids.sessionId), isEmpty);
  });
}
