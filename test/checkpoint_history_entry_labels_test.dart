import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/checkpoint_history_labels.dart';

String title(String operation, String description) =>
    CheckpointHistoryLabels.entryTitle(
      operationType: operation,
      description: description,
    );

void main() {
  test('translates automatic edit, addition, and deletion history titles', () {
    expect(title('edit', 'Edited line 17'), 'Edited subtitle 17');
    expect(title('add', 'Added line at position 2'), 'Added subtitle 2');
    expect(title('delete', 'Deleted line 4'), 'Deleted subtitle 4');
  });

  test('shows understandable split and merge labels', () {
    expect(title('split', 'Split line 12'),
        'Split subtitle 12 into two');
    expect(title('merge', 'Merged lines 6 and 7'),
        'Combined subtitles 6 and 7');
  });

  test('translates review mark and note changes made by annotation service',
      () {
    expect(title('annotation', 'Marked line 8'),
        'Marked subtitle 8 for review');
    expect(title('annotation', 'Unmarked line 8'),
        'Removed review mark from subtitle 8');
    expect(title('annotation', 'Updated comment on line 3'),
        'Updated note on subtitle 3');
    expect(title('annotation', 'Updated resolution of line 3'),
        'Updated review status of subtitle 3');
  });

  test('legacy edit-tagged annotation entries remain understandable', () {
    expect(title('edit', 'Marked line 10'),
        'Marked subtitle 10 for review');
    expect(title('edit', 'Updated comment on line 10'),
        'Updated note on subtitle 10');
  });

  test('shows initial version and imported external updates clearly', () {
    expect(title('snapshot', 'Initial state'), 'Project started');
    expect(title('sync', 'Captured external subtitle changes'),
        'Saved changes made outside the editor');
    expect(title('snapshot', ''), 'Saved project version');
    expect(title('snapshot', 'Snapshot'), 'Saved project version');
  });

  test('does not modify personally named manual save points', () {
    expect(title('manual', 'Before final translation'),
        'Before final translation');
    expect(title('manual', 'Edited line 8'), 'Edited line 8');
    expect(title('manual', 'Manual checkpoint'), 'Save point created');
    expect(title('manual', ''), 'Save point created');
    expect(title('manual', '  My important version  '),
        '  My important version  ');
  });

  test('unknown imported descriptions and mismatched types remain intact', () {
    expect(title('effect', 'Edited line 18'), 'Edited line 18');
    expect(title('add', 'Deleted line 20'), 'Deleted line 20');
    expect(title('legacy', 'Auto sync 04:15'), 'Auto sync 04:15');
    expect(title('annotation', 'Notes translated externally'),
        'Notes translated externally');
    expect(title('edit', 'Initial state'), 'Initial state');
  });

  test('empty older descriptions use a safe action label', () {
    expect(title('edit', ''), 'Edited subtitles');
    expect(title('effect', ''), 'Applied subtitle effect');
    expect(title('sync', ''), 'Updated subtitle timing');
    expect(title('unrecognized', ''), 'Saved change');
  });

  test('classic badges use recognizable names without schema edits', () {
    expect(CheckpointHistoryLabels.entryBadge(
        operationType: 'snapshot', checkpointType: 'snapshot'),
        'Saved version');
    expect(CheckpointHistoryLabels.entryBadge(
        operationType: 'manual', checkpointType: 'delta'),
        'Save point');
    expect(CheckpointHistoryLabels.entryBadge(
        operationType: 'manual', checkpointType: 'snapshot'),
        'Save point');
    expect(CheckpointHistoryLabels.entryBadge(
        operationType: 'edit', checkpointType: 'delta'),
        'Edit');
  });

  test('subtitle numbering is not inferred from unknown text', () {
    expect(title('edit', 'Edited line zero'), 'Edited line zero');
    expect(title('add', 'Added line at position 2 and 3'),
        'Added line at position 2 and 3');
    expect(title('merge', 'Merged lines 4 and 8'),
        'Combined subtitles 4 and 8');
  });
}
