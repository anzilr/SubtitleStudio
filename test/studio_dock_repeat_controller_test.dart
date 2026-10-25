import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_playback_link.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_repeat_controller.dart';
import 'package:subtitle_studio/widgets/video/subtitle.dart';

const cues = <Subtitle>[
  Subtitle(index: 1, start: Duration(milliseconds: 50),
      end: Duration(seconds: 2), text: 'First'),
  Subtitle(index: 2, start: Duration(seconds: 3),
      end: Duration(seconds: 4), text: 'Second'),
  Subtitle(index: 3, start: Duration(seconds: 5),
      end: Duration(seconds: 7), text: 'Third'),
];

void main() {
  test('current repeat clamps lead-in and loops without changing play state', () {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    link.updatePlaying(false);
    final repeat = StudioDockRepeatController(link)..updateCues(cues);
    expect(repeat.toggleCurrent(1), true);
    expect(seeks, [Duration.zero]);
    link.updatePosition(const Duration(milliseconds: 2100));
    expect(seeks, [Duration.zero, Duration.zero]);
    // Native seeks are asynchronous; do not issue another one while waiting.
    link.updatePosition(const Duration(milliseconds: 2200));
    expect(seeks.length, 2);
    link.updatePosition(const Duration(milliseconds: 200));
    link.updatePosition(const Duration(milliseconds: 2100));
    expect(seeks.length, 3);
    expect(link.playing.value, false);
    expect(repeat.toggleCurrent(1), false);
    link.updatePosition(const Duration(seconds: 5));
    expect(seeks.length, 3);
    repeat.dispose();
    link.dispose();
  });

  test('inclusive custom range uses first start and last end', () {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    final repeat = StudioDockRepeatController(link)..updateCues(cues);
    expect(repeat.setRange(1, 2), true);
    expect(repeat.isCustomRange, true);
    expect(seeks.single, const Duration(milliseconds: 2900));
    link.updatePosition(const Duration(milliseconds: 7099));
    expect(seeks.length, 1);
    link.updatePosition(const Duration(milliseconds: 7100));
    expect(seeks.last, const Duration(milliseconds: 2900));
    // Selection changes must not move a custom range.
    repeat.selectCue(1);
    expect(seeks.length, 2);
    expect(repeat.setRange(-1, 2), false);
    expect(repeat.setRange(2, 1), false);
    expect(repeat.setRange(0, 3), false);
    expect(repeat.isCustomRange, true);
    repeat.dispose();
    link.dispose();
  });

  test('normal repeat follows selected cue and edited times', () {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    final repeat = StudioDockRepeatController(link)..updateCues(cues);
    expect(repeat.setNormal(2), true);
    expect(seeks.last, const Duration(milliseconds: 2900));
    repeat.selectCue(3);
    expect(seeks.last, const Duration(milliseconds: 4900));
    repeat.updateCues([
      cues[0], cues[1],
      const Subtitle(index: 3, start: Duration(seconds: 6),
          end: Duration(seconds: 8), text: 'Retimed'),
    ]);
    link.updatePosition(const Duration(milliseconds: 8100));
    expect(seeks.last, const Duration(milliseconds: 5900));
    repeat.updateCues([cues[0], cues[1]]);
    expect(repeat.enabled, false);
    repeat.dispose();
    link.dispose();
  });

  test('paused detach clears repeat and never seeks disposed player', () {
    final link = StudioDockPlaybackLink();
    final seeks = <Duration>[];
    link.attach(seeks.add);
    final repeat = StudioDockRepeatController(link)..updateCues(cues);
    expect(repeat.toggleCurrent(2), true);
    link.detach();
    expect(repeat.enabled, false);
    link.updatePosition(const Duration(seconds: 20));
    expect(seeks.length, 1);
    link.attach(seeks.add);
    expect(repeat.enabled, false);
    repeat.dispose();
    link.updatePosition(const Duration(seconds: 30));
    expect(seeks.length, 1);
    link.dispose();
  });
}
