import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/models/edit_line_committed_cue.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_draft_save_service.dart';

SubtitleLine _line({String? edited = 'Earlier translation'}) => SubtitleLine()
  ..index = 3
  ..startTime = '00:00:02,000'
  ..endTime = '00:00:03,000'
  ..original = 'Earlier source'
  ..edited = edited
  ..marked = true
  ..comment = 'Review this'
  ..resolved = false;

EditLineCommittedCue _committed(SubtitleLine line) =>
    EditLineCommittedCue(selectedLine: line, lines: [line]);

Future<EditLineDraftSaveResult> _save(
  EditLineDraftSaveService service,
  SubtitleLine line, {
  bool editMode = false,
  bool insert = false,
  String editedText = '',
}) {
  return service.save(
    currentLine: line,
    originalText: 'Updated source',
    editedText: editedText,
    startTime: '00:00:04,000',
    endTime: '00:00:05,000',
    initialOriginalText: 'Earlier source',
    initialStartTime: '00:00:02,000',
    initialEndTime: '00:00:03,000',
    isEditMode: editMode,
    insertLine: insert,
    insertIndex: 7,
  );
}

void main() {
  test('manual and autosave share a detached blank-cue checkpoint plan',
      () async {
    for (final mode in ['manual', 'autosave']) {
      final originalLine = _line();
      late SubtitleLine stored;
      late SubtitleLine before;
      final indices = <int>[];
      final service = EditLineDraftSaveService(
        saveExisting: (line, {beforeLine}) async {
          stored = line;
          before = beforeLine!;
          return _committed(line);
        },
        insertNew: (_, __) async => fail('Unexpected insert in $mode'),
        updateLastEditedIndex: (index) async => indices.add(index),
      );

      final outcome = await _save(service, originalLine);
      expect(outcome.saved, isTrue);
      expect(identical(outcome.savedLine, originalLine), isFalse);
      expect(stored.edited, '', reason: '$mode must preserve blank edits');
      expect(stored.original, 'Updated source');
      expect(stored.startTime, '00:00:04,000');
      expect(stored.endTime, '00:00:05,000');
      expect(stored.marked, isTrue);
      expect(stored.comment, 'Review this');
      expect(stored.resolved, isFalse);

      expect(before.original, 'Earlier source');
      expect(before.edited, 'Earlier translation');
      expect(before.startTime, '00:00:02,000');
      expect(before.endTime, '00:00:03,000');
      expect(before.comment, 'Review this');
      expect(indices, [3]);

      // Nothing in the screen's current line changes until it applies the
      // accepted result. Failure therefore cannot leak a draft into preview.
      expect(originalLine.edited, 'Earlier translation');
      expect(originalLine.original, 'Earlier source');
      expect(originalLine.startTime, '00:00:02,000');
    }
  });

  test('edit mode retains source text and encodes only draft line breaks',
      () async {
    final current = _line(edited: null);
    late SubtitleLine saved;
    final service = EditLineDraftSaveService(
      saveExisting: (line, {beforeLine}) async {
        saved = line;
        expect(beforeLine!.edited, isNull);
        return _committed(line);
      },
      insertNew: (_, __) async => null,
      updateLastEditedIndex: (_) async {},
    );

    expect((await _save(service, current,
        editMode: true, editedText: 'First\n\nSecond')).saved, isTrue);
    expect(saved.original, 'Earlier source');
    expect(saved.edited, 'First<br><br>Second');
    expect(current.edited, isNull);
  });

  test('rejected existing write does not record index or mutate current cue',
      () async {
    final current = _line();
    var indexUpdates = 0;
    final service = EditLineDraftSaveService(
      saveExisting: (_, {beforeLine}) async => null,
      insertNew: (_, __) async => null,
      updateLastEditedIndex: (_) async { indexUpdates++; },
    );

    final result = await _save(service, current);
    expect(result.saved, isFalse);
    expect(result.savedLine, isNull);
    expect(indexUpdates, 0);
    expect(current.edited, 'Earlier translation');
    expect(current.startTime, '00:00:02,000');
  });

  test('new cue insertion is acknowledged only when its transaction succeeds',
      () async {
    final current = _line();
    var accept = false;
    final indices = <int>[];
    final service = EditLineDraftSaveService(
      saveExisting: (_, {beforeLine}) async => fail('Unexpected edit'),
      insertNew: (line, index) async {
        expect(index, 7);
        expect(line.edited, 'New cue');
        return accept ? _committed(line) : null;
      },
      updateLastEditedIndex: (index) async => indices.add(index),
    );

    expect((await _save(service, current, insert: true,
        editedText: 'New cue')).saved, isFalse);
    expect(indices, isEmpty);
    accept = true;
    expect((await _save(service, current, insert: true,
        editedText: 'New cue')).saved, isTrue);
    expect(indices, [3]);
  });

  test('noncritical last-index failure cannot undo an accepted checkpoint',
      () async {
    final errors = <Object>[];
    final service = EditLineDraftSaveService(
      saveExisting: (line, {beforeLine}) async => _committed(line),
      insertNew: (_, __) async => null,
      updateLastEditedIndex: (_) async => throw StateError('index denied'),
      onIndexUpdateError: (error, _) => errors.add(error),
    );

    expect((await _save(service, _line())).saved, isTrue);
    expect(errors, hasLength(1));
  });
  test('committed position determines session last edited index',
      () async {
    final original = _line();
    final updated = _line()..index = 1;
    final neighbor = _line()
      ..index = 2
      ..original = 'Neighbor';
    final savedIndices = <int>[];
    final service = EditLineDraftSaveService(
      saveExisting: (_, {beforeLine}) async => EditLineCommittedCue(
        selectedLine: updated,
        lines: [updated, neighbor],
      ),
      insertNew: (_, __) async => null,
      updateLastEditedIndex: (index) async => savedIndices.add(index),
    );
    final result = await _save(service, original);
    expect(result.saved, isTrue);
    expect(result.savedLine!.index, 1);
    expect(result.persistedLines!.map((line) => line.index), [1, 2]);
    expect(savedIndices, [1]);
    expect(original.index, 3);
  });
}
