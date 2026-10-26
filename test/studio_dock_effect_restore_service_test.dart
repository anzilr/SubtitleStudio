import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_restore_service.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_snapshot.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';

StudioDockSessionSnapshot snapshotFor(List<String> frames, {
    bool imported = false}) => StudioDockSessionSnapshot(
  sessionId: 3,
  collectionId: 5,
  fileName: 'example.srt',
  encoding: 'UTF-8',
  cues: [
    for (var i = 0; i < frames.length; i++)
      StudioDockLoadedCue(
        index: i + 1,
        start: '00:00:0${i + 1},000',
        end: '00:00:0${i + 2},000',
        original: imported
            ? frames[i].replaceAll(RegExp(r'<[^>]*>'), '')
            : 'Original dialogue',
        edited: imported ? '' : frames[i],
        storedEdited: imported ? null : frames[i],
        marked: i == 1,
        resolved: i != 1,
        comment: i == 1 ? 'Needs review' : null,
      ),
  ],
);

void main() {
  test('generated bundle restores one caption and keeps review metadata', () {
    const caption = 'One two three four';
    final frames = SrtEffectFrames.build(
      effect: 'spotlightKaraoke', text: caption, color: 'FFAA00',
      availableMilliseconds: 4000,
    );
    final baseline = snapshotFor(frames);
    final groups = StudioDockEffectRestoreService.detect(baseline);
    expect(groups, hasLength(1));
    final restored = StudioDockEffectRestoreService.restoredCue(
        baseline, groups.single);
    expect(restored.index, 1);
    expect(restored.startTime, baseline.cues.first.start);
    expect(restored.endTime, baseline.cues.last.end);
    expect(restored.original, 'Original dialogue');
    expect(restored.edited, caption);
    expect(restored.marked, isTrue);
    expect(restored.resolved, isFalse);
    expect(restored.comment, 'Needs review');
  });

  test('imported unedited SRT effect restores readable original', () {
    final frames = SrtEffectFrames.build(effect: 'typewriterCursor',
        text: 'Hello', color: 'FFFFFF', availableMilliseconds: 4000);
    final baseline = snapshotFor(frames, imported: true);
    final group = StudioDockEffectRestoreService.detect(baseline).single;
    final restored = StudioDockEffectRestoreService.restoredCue(baseline, group);
    expect(restored.original, 'Hello');
    expect(restored.edited, isNull);
    expect(restored.startTime, baseline.cues.first.start);
    expect(restored.endTime, baseline.cues.last.end);
  });
}
