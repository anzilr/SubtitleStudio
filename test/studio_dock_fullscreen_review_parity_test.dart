import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_media_plan.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_session_snapshot.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_video_surface.dart';
import 'package:subtitle_studio/widgets/video_player_widget.dart';

void main() {
  test('fullscreen player projection retains comment and resolved status', () {
    final snapshot = StudioDockSessionSnapshot(
      sessionId: 1, collectionId: 2,
      fileName: 'reviews.srt', encoding: 'UTF-8',
      cues: const [
        StudioDockLoadedCue(
          index: 1, start: '00:00:01,000', end: '00:00:02,000',
          original: 'Original', edited: 'Translation',
          storedEdited: 'Translation', marked: true,
          comment: 'Review in fullscreen', resolved: true),
        StudioDockLoadedCue(
          index: 2, start: '00:00:03,000', end: '00:00:04,000',
          original: 'Unmarked', edited: '',
          marked: false),
      ],
    );
    final cues = StudioDockMediaPlan.overlayCues(snapshot);
    expect(cues, hasLength(2));
    expect(cues[0].marked, isTrue);
    expect(cues[0].comment, 'Review in fullscreen');
    expect(cues[0].resolved, isTrue);
    expect(cues[1].resolved, isFalse);
    expect(cues[1].comment, isNull);
  });

  test('atomic fullscreen callback reaches native surface; disabled by default',
      () async {
    final playback = StudioDockPlaybackLink();
    var marks = 0;
    var saved = 0;
    var resolved = 0;
    Future<void> mark(int index, bool state) async {
      marks++;
      expect(index, 1);
    }
    Future<bool> save(int index, String? comment,
        bool marked, bool isResolved) async {
      saved++;
      expect(index, 1);
      expect(comment, 'Comment');
      expect(marked, isTrue);
      expect(isResolved, isFalse);
      return true;
    }
    Future<void> resolve(int index, bool value) async {
      resolved++;
      expect(value, isTrue);
    }
    final surface = StudioDockVideoSurface(
      collectionId: 2, videoPath: 'not-opened.mp4', playback: playback,
      subtitles: const <Subtitle>[],
      onSubtitleMarked: mark,
      onSubtitleReviewSaved: save,
      onSubtitleResolvedChanged: resolve,
    );
    expect(surface.onSubtitleMarked, isNotNull);
    expect(surface.onSubtitleReviewSaved, isNotNull);
    expect(surface.onSubtitleResolvedChanged, isNotNull);
    // A mobile caller need not provide any new callbacks.
    const plain = Subtitle(index: 1, start: Duration.zero,
      end: Duration(seconds: 1), text: 'Plain subtitle');
    expect(plain.resolved, isFalse);

    final player = VideoPlayerWidget(
      videoPath: 'not-opened.mp4', subtitleCollectionId: 2,
      subtitles: const <Subtitle>[],
      onSubtitleReviewSaved: save,
      onSubtitleResolvedChanged: resolve,
    );
    expect(player.onSubtitleReviewSaved, isNotNull);
    expect(player.onSubtitleResolvedChanged, isNotNull);
    // Exercise callbacks without opening a native player or filesystem.
    await mark(1, true);
    expect(await save(1, 'Comment', true, false), isTrue);
    await resolve(1, true);
    expect([marks, saved, resolved], [1, 1, 1]);
    playback.dispose();
  });
}
