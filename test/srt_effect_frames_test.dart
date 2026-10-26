import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_groups.dart';
import 'package:subtitle_studio/operations/subtitle_effect_operations.dart';
import 'package:subtitle_studio/operations/srt_effect_frames.dart';
import 'package:subtitle_studio/utils/time_parser.dart';

SubtitleLine source(String text) => SubtitleLine()
  ..index = 1
  ..original = text
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:04,000'
  ..marked = true;

void main() {
  test('six new SRT effects generate timed frames and fold after export', () async {
    final examples = <String, String>{
      'wordReveal': 'One two three four',
      'movingKaraoke': 'One two three four',
      'activeTypewriter': 'കാ👩‍👩‍👧‍👦 Hello',
      'backspace': 'Delete this text',
      'lineReveal': 'One\nTwo\nThree\nFour',
      'colorTransition': 'Same words',
    };
    for (final example in examples.entries) {
      final original = source(example.value);
      final generated = await SubtitleEffectOperations.generateSrtEffect(
        originalLine: original, effect: example.key,
        color: 'FFFFFF', alternateColor: 'FF0000', endDelay: .25,
      );
      expect(generated.length, greaterThanOrEqualTo(3),
          reason: example.key);
      expect(generated.every((line) => line.marked), isTrue);
      expect(generated.first.startTime, original.startTime);
      expect(generated.last.endTime, original.endTime);
      for (var i = 0; i < generated.length; i++) {
        final line = generated[i];
        expect(line.index, i + 1);
        expect(parseTimeString(line.endTime).inMilliseconds,
            greaterThan(parseTimeString(line.startTime).inMilliseconds));
        if (i > 0) expect(line.startTime, generated[i - 1].endTime);
      }
      final detected = StudioDockEffectGroups.detect([
        for (final line in generated) StudioDockEffectFrame(
          id: line.index, start: line.startTime, end: line.endTime,
          original: line.original, edited: line.edited!,
        ),
      ]);
      expect(detected, hasLength(1), reason: example.key);
      expect(detected.single.length, generated.length,
          reason: example.key);
    }
  });

  test('active-character frames never split Malayalam or emoji graphemes', () {
    const content = 'കാ👩‍👩‍👧‍👦é';
    final frames = SrtEffectFrames.build(effect: 'activeTypewriter',
        text: content, color: 'FFFFFF', alternateColor: 'FFFF00',
        availableMilliseconds: 2000);
    expect(frames, hasLength(content.characters.length));
    for (var i = 0; i < frames.length; i++) {
      final rendered = frames[i].replaceAll(RegExp(r'<[^>]*>'), '');
      expect(rendered, content.characters.take(i + 1).join());
    }
  });

  test('invalid and too-short effects fail closed', () async {
    expect(SrtEffectFrames.build(effect: 'unsupported', text: 'Hello',
        color: 'FFFFFF', availableMilliseconds: 500), isEmpty);
    expect(await SubtitleEffectOperations.generateSrtEffect(
        originalLine: source(''), effect: 'wordReveal', color: 'FFFFFF'),
        isEmpty);
    expect(await SubtitleEffectOperations.generateSrtEffect(
        originalLine: source('Sample')
          ..endTime = '00:00:01,000',
        effect: 'backspace', color: 'FFFFFF'), isEmpty);
  });

  test('collapsed effect targets every cue; expanded target is one cue', () {
    final group = StudioDockEffectGroup(
      frames: [
        for (var i = 1; i <= 4; i++) StudioDockEffectFrame(
          id: i, start: '00:00:0$i,000', end: '00:00:0$i,500',
          original: 'Example', edited: 'Example',
        ),
      ],
      kind: StudioDockEffectKind.wordReveal,
      previewText: 'Example',
    );
    expect(StudioDockEffectMarks.targets(2), [2]);
    expect(StudioDockEffectMarks.targets(2, collapsedGroup: group),
        [1, 2, 3, 4]);
    expect(StudioDockEffectMarks.state(group, {}),
        StudioDockEffectMarkState.none);
    expect(StudioDockEffectMarks.state(group, {2}),
        StudioDockEffectMarkState.partial);
    expect(StudioDockEffectMarks.state(group, {1, 2, 3, 4}),
        StudioDockEffectMarkState.all);
  });
}
