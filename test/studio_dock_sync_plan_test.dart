import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_bulk_tools_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_snapshot.dart';

StudioDockSessionSnapshot example() => StudioDockSessionSnapshot(
  sessionId: 1, collectionId: 2, fileName: 'demo.srt', encoding: 'UTF-8',
  cues: const [
    StudioDockLoadedCue(index: 1, start: '00:00:01,000',
        end: '00:00:02,000', original: 'First', edited: '',
        storedEdited: 'Translated', marked: true,
        comment: 'Review', resolved: true),
    StudioDockLoadedCue(index: 2, start: '00:00:03,000',
        end: '00:00:04,000', original: 'Second', edited: '',
        marked: false),
    StudioDockLoadedCue(index: 3, start: '00:00:05,000',
        end: '00:00:06,000', original: 'Third', edited: '',
        marked: false),
  ],
);

void main() {
  test('Anchored sync matches mobile relative-start scaling and keeps durations', () {
    final result = StudioDockBulkToolsService.planAnchoredSync(
        example(), '00:00:02,000', '00:00:12,000');
    expect(result.map((c) => c.startTime).toList(), [
      '00:00:02,000', '00:00:06,000', '00:00:10,000']);
    expect(result.map((c) => c.endTime).toList(), [
      '00:00:03,000', '00:00:07,000', '00:00:11,000']);
    expect(result.first.original, 'First');
    expect(result.first.edited, 'Translated');
    expect(result.first.marked, isTrue);
    expect(result.first.comment, 'Review');
    expect(result.first.resolved, isTrue);
  });

  test('FPS conversion scales both bounds and retains all metadata', () {
    final result = StudioDockBulkToolsService.planFramerate(
        example(), 25, 50);
    expect(result.first.startTime, '00:00:00,500');
    expect(result.first.endTime, '00:00:01,000');
    expect(result.last.startTime, '00:00:02,500');
    expect(result.last.endTime, '00:00:03,000');
    expect(result.first.edited, 'Translated');
    expect(result.first.comment, 'Review');
    expect(result.first.resolved, isTrue);
  });

  test('rejects invalid framerates before attempting persistence', () {
    for (final frame in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => StudioDockBulkToolsService.planFramerate(
          example(), frame, 25), throwsFormatException);
      expect(() => StudioDockBulkToolsService.planFramerate(
          example(), 25, frame), throwsFormatException);
    }
  });

  test('rejects noncanonical and reversed anchor ranges', () {
    expect(() => StudioDockBulkToolsService.planAnchoredSync(
        example(), 'invalid', '00:00:12,000'), throwsFormatException);
    expect(() => StudioDockBulkToolsService.planAnchoredSync(
        example(), '00:00:12,000', '00:00:02,000'), throwsFormatException);
  });

  test('rejects SRT time overflow on large FPS conversion', () {
    final late = StudioDockSessionSnapshot(
      sessionId: 1, collectionId: 2, fileName: 'late.srt',
      encoding: 'UTF-8', cues: const [
        StudioDockLoadedCue(index: 1, start: '23:59:58,000',
            end: '23:59:59,000', original: 'late', edited: '',
            marked: false),
      ],
    );
    expect(() => StudioDockBulkToolsService.planFramerate(
        late, 50, 25), throwsFormatException);
  });
}
