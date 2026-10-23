import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_state.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_selection_projection.dart';

SubtitleLine _cue(int index, String original, String? edited,
    {String start = '00:00:01,000', String? comment}) => SubtitleLine()
  ..index = index
  ..original = original
  ..edited = edited
  ..startTime = start
  ..endTime = '00:00:05,000'
  ..marked = comment != null
  ..comment = comment
  ..resolved = false;

SubtitleCollection _collection(List<SubtitleLine> lines) =>
    SubtitleCollection(
      fileName: 'sample.srt',
      filePath: '/tmp/sample.srt',
      originalFileUri: 'content://provider/doc/123',
      encoding: 'UTF-16LE',
      macOsSrtBookmark: 'scoped-bookmark',
      lines: lines,
    )..id = 47;

void main() {
  test('committed reordering updates selection without mutating old state',
      () {
    final one = _cue(1, 'One', 'First edit', comment: 'Review me');
    final two = _cue(2, 'Two', null);
    final collection = _collection([one, two]);
    final before = EditLineState(
      sessionId: 7,
      subtitleCollection: collection,
      subtitleLine: one,
      originalText: one.original,
      editedText: 'First edit',
      startTime: one.startTime,
      endTime: one.endTime,
      hasUnsavedChanges: true,
    );

    final moved = _cue(2, 'One', '', start: '00:00:06,000',
        comment: 'Review me');
    final sortedNeighbor = _cue(1, 'Two', null);
    final next = EditLineSelectionProjection.apply(
      current: before,
      collection: collection,
      selectedLine: moved,
      orderedLines: [sortedNeighbor, moved],
    );

    expect(next.subtitleLine!.index, 2);
    expect(next.subtitleLine!.original, 'One');
    expect(next.subtitleLine!.edited, '');
    expect(next.subtitleLine!.comment, 'Review me');
    expect(next.subtitleCollection!.lines.map((line) => line.original),
        ['Two', 'One']);
    expect(next.hasUnsavedChanges, isFalse);

    // Prior listeners and cached Isar objects retain the original order.
    expect(before.subtitleLine!.index, 1);
    expect(before.subtitleCollection!.lines.map((line) => line.original),
        ['One', 'Two']);
    expect(identical(next.subtitleCollection, collection), isFalse);
    expect(identical(next.subtitleLine, moved), isFalse);
    moved.original = 'Changed after commit';
    expect(next.subtitleLine!.original, 'One');
  });

  test('preserves file identity, encoding, bookmark, and cue metadata',
      () {
    final original = _cue(1, 'Source', 'Translation', comment: 'Check');
    original.resolved = true;
    final collection = _collection([original]);
    final next = EditLineSelectionProjection.apply(
      current: EditLineState(sessionId: 2, subtitleCollection: collection),
      collection: collection,
      selectedLine: original,
      orderedLines: [original],
    );
    expect(next.subtitleCollection!.id, 47);
    expect(next.subtitleCollection!.fileName, 'sample.srt');
    expect(next.subtitleCollection!.filePath, '/tmp/sample.srt');
    expect(next.subtitleCollection!.originalFileUri, 'content://provider/doc/123');
    expect(next.subtitleCollection!.encoding, 'UTF-16LE');
    expect(next.subtitleCollection!.macOsSrtBookmark, 'scoped-bookmark');
    expect(next.subtitleLine!.marked, isTrue);
    expect(next.subtitleLine!.comment, 'Check');
    expect(next.subtitleLine!.resolved, isTrue);
  });

  test('keeps deliberate blank edits separate from unedited source',
      () {
    final blank = _cue(1, 'Never erase source', '');
    final collection = _collection([blank]);
    final state = EditLineSelectionProjection.apply(
      current: EditLineState(sessionId: 2),
      collection: collection,
      selectedLine: blank,
      orderedLines: [blank],
    );
    expect(state.originalText, 'Never erase source');
    expect(state.editedText, '');
    expect(state.subtitleLine!.edited, '');
    final unedited = _cue(1, 'Source remains', null);
    final second = EditLineSelectionProjection.apply(
      current: state,
      collection: collection,
      selectedLine: unedited,
      orderedLines: [unedited],
    );
    expect(second.subtitleLine!.edited, isNull);
    expect(second.editedText, '');
  });

  test('multiline edits are projected as visible newline text', () {
    final line = _cue(1, 'Original', 'First<br><br>Third');
    final col = _collection([line]);
    final projected = EditLineSelectionProjection.apply(
      current: EditLineState(sessionId: 2),
      collection: col,
      selectedLine: line,
      orderedLines: [line],
    );
    expect(projected.editedText, 'First\n\nThird');
    expect(projected.subtitleLine!.edited, 'First<br><br>Third');

    final visibleOverride = EditLineSelectionProjection.apply(
      current: projected,
      collection: col,
      selectedLine: line,
      orderedLines: [line],
      displayedEditedText: 'Use original text for display',
    );
    expect(visibleOverride.editedText, 'Use original text for display');
    expect(visibleOverride.subtitleLine!.edited, 'First<br><br>Third');
  });

  test('new unsaved cue is selected without adding it to persisted rows', () {
    final existing = _cue(1, 'Existing', null);
    final nextDraft = _cue(2, '', '');
    final col = _collection([existing]);
    final next = EditLineSelectionProjection.apply(
      current: EditLineState(sessionId: 2),
      collection: col,
      selectedLine: nextDraft,
      orderedLines: col.lines,
    );
    expect(next.subtitleLine!.index, 2);
    expect(next.subtitleLine!.original, '');
    expect(next.subtitleCollection!.lines, hasLength(1));
    expect(col.lines, hasLength(1));
  });

  test('new selection clears stale validation while retaining other UI state',
      () {
    final line = _cue(1, 'Text', null);
    final col = _collection([line]);
    final before = EditLineState(
      sessionId: 55,
      subtitleCollection: col,
      startTimeError: 'invalid',
      endTimeError: 'invalid',
      timeOrderError: 'invalid',
      errorMessage: 'could not load',
      isLoading: true,
      hasUnsavedChanges: true,
      videoPath: '/media/video.mkv',
      isVideoLoaded: true,
      resizeRatio: 0.45,
    );
    final next = EditLineSelectionProjection.apply(
      current: before,
      collection: col,
      selectedLine: line,
      orderedLines: col.lines,
    );
    expect(next.startTimeError, isNull);
    expect(next.endTimeError, isNull);
    expect(next.timeOrderError, isNull);
    expect(next.errorMessage, isNull);
    expect(next.isLoading, isFalse);
    expect(next.hasUnsavedChanges, isFalse);
    expect(next.sessionId, 55);
    expect(next.videoPath, '/media/video.mkv');
    expect(next.isVideoLoaded, isTrue);
    expect(next.resizeRatio, 0.45);
  });
}
