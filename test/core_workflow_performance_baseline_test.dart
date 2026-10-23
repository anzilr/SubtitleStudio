import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/services/editor_direct_save_service.dart';
import 'package:subtitle_studio/services/checkpoint_history_metadata.dart';
import 'package:subtitle_studio/services/checkpoint_reconstructor.dart';
import 'package:subtitle_studio/services/checkpoint_state_hasher.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/services/checkpoint_store.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/subtitle_processor.dart';

import 'support/test_isar_harness.dart';

// Diagnostic baseline, not a latency assertion. Shared Linux runners have
// variable CPU and IO throughput, so CI verifies the operations and prints
// comparable measurements without imposing environment-specific thresholds.
const _cueCount = 1000;
const _iterations = 3;

String _timestamp(int milliseconds) {
  final hours = milliseconds ~/ 3600000;
  final minutes = (milliseconds ~/ 60000) % 60;
  final seconds = (milliseconds ~/ 1000) % 60;
  final ms = milliseconds % 1000;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')},'
      '${ms.toString().padLeft(3, '0')}';
}

String _syntheticSrt() {
  final output = StringBuffer();
  for (var index = 1; index <= _cueCount; index++) {
    final start = index * 2400;
    output.writeln(index);
    output.writeln(
      '${_timestamp(start)} --> ${_timestamp(start + 1800)}',
    );
    if (index % 31 == 0) {
      // Preserve intentionally empty cues through import/open/save/restore.
      output.writeln();
    } else if (index % 17 == 0) {
      output.writeln('Synthetic line $index\n\ncontinued മലയാളം');
    } else {
      output.writeln('Synthetic line $index');
    }
    output.writeln();
  }
  return output.toString();
}

String _summary(List<int> microseconds) {
  final ordered = [...microseconds]..sort();
  String millis(int value) => (value / 1000).toStringAsFixed(2);
  return 'median_ms=${millis(ordered[ordered.length ~/ 2])} '
      'max_ms=${millis(ordered.last)}';
}

void main() {
  test('CP92 R6 synthetic import/open/save/restore performance baseline',
      () async {
    final harness = await TestIsarHarness.open();
    addTearDown(harness.close);
    final repository = SubtitleImportRepository(harness.isar);
    final store = CheckpointStore(harness.isar);
    final save = EditorDirectSaveService(isMacOS: false);
    final source = _syntheticSrt();
    final importedTimes = <int>[];
    final openedTimes = <int>[];
    final savedTimes = <int>[];
    final restoredTimes = <int>[];

    // Parser/Isar setup and temporary output creation are outside the four
    // timers. No real user file or SAF locator participates in this test.
    expect(SubtitleParser.parseSrt(source), hasLength(_cueCount));
    final output = File('${harness.directory.path}/synthetic_output.srt');
    await output.writeAsBytes(const [1]);

    for (var repetition = 0; repetition < _iterations; repetition++) {
      var watch = Stopwatch()..start();
      final imported = await processSubtitleContentWithoutContext(
        source,
        'synthetic.srt',
        '/synthetic/document.srt',
        repository: repository,
        encoding: 'UTF-8',
      );
      watch.stop();
      importedTimes.add(watch.elapsedMicroseconds);

      watch = Stopwatch()..start();
      final opened = await harness.isar.subtitleCollections.get(
        imported.subtitleCollectionId,
      );
      watch.stop();
      openedTimes.add(watch.elapsedMicroseconds);
      expect(opened, isNotNull);
      expect(opened!.lines, hasLength(_cueCount));

      // The Editor's normal direct save validates encoding and writes to an
      // existing native destination. The temporary file remains outside Isar.
      final saveSource = SubtitleCollection(
        fileName: 'synthetic.srt',
        encoding: opened.encoding,
        filePath: output.path,
        originalFileUri: output.path,
        lines: opened.lines,
      );
      watch = Stopwatch()..start();
      final saved = await save.save(saveSource, opened.lines);
      watch.stop();
      savedTimes.add(watch.elapsedMicroseconds);
      expect(saved.saved, isTrue);

      final rootLines = CheckpointStateReducer.copyLines(opened.lines);
      final editedLines = CheckpointStateReducer.copyLines(rootLines);
      editedLines.first.edited = 'Synthetic review $repetition';
      final workingLines = CheckpointStateReducer.copyLines(editedLines);
      workingLines[1].edited = 'Synthetic newer edit $repetition';
      final rootHash = CheckpointStateHasher.hashLines(rootLines);
      final editedHash = CheckpointStateHasher.hashLines(editedLines);
      final workingHash = CheckpointStateHasher.hashLines(workingLines);

      final root = Checkpoint(
        sessionId: imported.sessionId,
        subtitleCollectionId: imported.subtitleCollectionId,
        timestamp: DateTime.utc(2026, 10, 23),
        operationType: 'snapshot',
        description: 'Initial state',
        isActive: false,
        checkpointType: 'snapshot',
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          stateHash: rootHash,
        ),
        deltas: const [],
        snapshot: rootLines,
      );
      final rootId = await store.putCheckpoint(root);
      root.id = rootId;
      final target = Checkpoint(
        sessionId: imported.sessionId,
        subtitleCollectionId: imported.subtitleCollectionId,
        timestamp: DateTime.utc(2026, 10, 23, 0, 1),
        operationType: 'edit',
        description: 'Edited first cue',
        parentCheckpointId: rootId,
        isActive: false,
        checkpointType: 'delta',
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          stateHash: editedHash,
          parentStateHash: rootHash,
        ),
        deltas: [
          SubtitleLineDelta()
            ..changeType = 'modify'
            ..lineIndex = 0
            ..beforeState = CheckpointStateReducer.copyLine(rootLines.first)
            ..afterState = CheckpointStateReducer.copyLine(editedLines.first),
        ],
        snapshot: const [],
      );
      final targetId = await store.putCheckpoint(target);
      target.id = targetId;
      final head = Checkpoint(
        sessionId: imported.sessionId,
        subtitleCollectionId: imported.subtitleCollectionId,
        timestamp: DateTime.utc(2026, 10, 23, 0, 2),
        operationType: 'edit',
        description: 'Newer edit',
        parentCheckpointId: targetId,
        isActive: true,
        checkpointType: 'delta',
        metadata: CheckpointHistoryMetadata.encodePostOperation(
          stateHash: workingHash,
          parentStateHash: editedHash,
        ),
        deltas: [
          SubtitleLineDelta()
            ..changeType = 'modify'
            ..lineIndex = 1
            ..beforeState = CheckpointStateReducer.copyLine(editedLines[1])
            ..afterState = CheckpointStateReducer.copyLine(workingLines[1]),
        ],
        snapshot: const [],
      );
      final headId = await store.putCheckpoint(head);
      head.id = headId;
      opened.lines = workingLines;
      await store.saveSubtitleCollection(opened);

      watch = Stopwatch()..start();
      final restoredLines = CheckpointReconstructor.reconstructPostOperation(
        checkpoints: [root, target, head],
        targetCheckpointId: targetId,
      );
      final destination = (await store.getSubtitleCollection(
        imported.subtitleCollectionId,
      ))!..lines = restoredLines;
      await store.restoreCollectionAndActivateOnly(
        sessionId: imported.sessionId,
        targetCheckpoint: target,
        collection: destination,
        expectedHeadId: headId,
        expectedWorkingStateHash: workingHash,
      );
      watch.stop();
      restoredTimes.add(watch.elapsedMicroseconds);

      final checkedOut = await store.getSubtitleCollection(
        imported.subtitleCollectionId,
      );
      expect(checkedOut!.lines, hasLength(_cueCount));
      expect(checkedOut.lines.first.edited, 'Synthetic review $repetition');
      expect(checkedOut.lines[1].edited, isNull);
      expect((await store.getCurrentHeadCheckpoint(imported.sessionId))!.id,
          targetId);
    }

    final decoded = SubtitleTextCodec.decode(await output.readAsBytes());
    expect(SubtitleParser.parseSrt(decoded.content), hasLength(_cueCount));
    expect(importedTimes, hasLength(_iterations));
    expect(restoredTimes, hasLength(_iterations));

    // Only stage names, fixture sizes and aggregate durations are printed.
    // No source paths, subtitle text, metadata or native process output.
    // ignore: avoid_print
    print('CP92_R6_BASELINE cues=$_cueCount repeats=$_iterations '
        'import ${_summary(importedTimes)} | '
        'open ${_summary(openedTimes)} | '
        'save ${_summary(savedTimes)} | '
        'restore ${_summary(restoredTimes)}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
