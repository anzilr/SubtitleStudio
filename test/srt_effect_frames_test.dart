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

  test('moving karaoke supports word and grapheme-by-grapheme highlight',
      () async {
    const caption = 'കാ👩‍👩‍👧‍👦 é!';
    final meaningful = caption.characters
        .where((glyph) => glyph.trim().isNotEmpty).toList();
    final byWord = SrtEffectFrames.build(effect: 'movingKaraoke',
        text: caption, color: '22FF33', availableMilliseconds: 3000);
    expect(byWord, hasLength(2));

    final byCharacter = SrtEffectFrames.build(effect: 'movingKaraoke',
        text: caption, color: '22FF33', unit: 'character',
        availableMilliseconds: 3000);
    expect(byCharacter, hasLength(meaningful.length));
    final highlight = RegExp(r'<font color="#22FF33">(.*?)</font>', dotAll: true);
    for (var i = 0; i < byCharacter.length; i++) {
      expect(byCharacter[i].replaceAll(RegExp(r'<[^>]*>'), ''), caption);
      expect(highlight.firstMatch(byCharacter[i])?.group(1), meaningful[i]);
      expect(highlight.allMatches(byCharacter[i]), hasLength(1));
    }

    final generated = await SubtitleEffectOperations.generateSrtEffect(
        originalLine: source(caption), effect: 'movingKaraoke',
        unit: 'character', color: '22FF33', endDelay: .5);
    expect(generated, hasLength(meaningful.length));
    expect(generated.first.startTime, '00:00:01,000');
    expect(generated.last.endTime, '00:00:04,000');
    final groups = StudioDockEffectGroups.detect([
      for (final line in generated) StudioDockEffectFrame(
          id: line.index, start: line.startTime, end: line.endTime,
          original: line.original, edited: line.edited!),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.kind, StudioDockEffectKind.movingKaraoke);
    expect(groups.single.length, meaningful.length);
    expect(groups.single.previewText, caption);
  });

  test('batch 2 effects export timed SRT cues and fold into their own group', () async {
    const content = 'കാ👩‍👩‍👧‍👦é Hello';
    const kinds = <String, StudioDockEffectKind>{
      'blinkFlash': StudioDockEffectKind.blink,
      'rainbowText': StudioDockEffectKind.rainbow,
      'scrambleReveal': StudioDockEffectKind.scrambleReveal,
    };
    for (final entry in kinds.entries) {
      final original = source(content);
      final generated = await SubtitleEffectOperations.generateSrtEffect(
        originalLine: original,
        effect: entry.key,
        color: 'FFFFFF',
        endDelay: .8,
      );
      expect(generated.length, greaterThanOrEqualTo(4), reason: entry.key);
      expect(generated.first.startTime, original.startTime);
      expect(generated.last.endTime, original.endTime);
      expect(generated.every((line) => line.marked), isTrue);
      for (var i = 0; i < generated.length; i++) {
        final line = generated[i];
        expect(line.index, i + 1);
        expect(parseTimeString(line.endTime).inMilliseconds,
            greaterThan(parseTimeString(line.startTime).inMilliseconds));
        if (i > 0) expect(line.startTime, generated[i - 1].endTime);
      }
      final groups = StudioDockEffectGroups.detect([
        for (final line in generated)
          StudioDockEffectFrame(
            id: line.index,
            start: line.startTime,
            end: line.endTime,
            original: line.original,
            edited: line.edited!,
          ),
      ]);
      expect(groups, hasLength(1), reason: entry.key);
      expect(groups.single.kind, entry.value, reason: entry.key);
      expect(groups.single.length, generated.length, reason: entry.key);
      expect(groups.single.previewText, content, reason: entry.key);
    }
  });

  test('batch 3 effects preserve complete graphemes and restore preview', () async {
    const caption = 'കാ 👩‍👩‍👧‍👦 é Story';
    const effects = <String, StudioDockEffectKind>{
      'spotlightKaraoke': StudioDockEffectKind.spotlightKaraoke,
      'typewriterCursor': StudioDockEffectKind.typewriterCursor,
      'centerOutReveal': StudioDockEffectKind.centerOutReveal,
    };
    for (final entry in effects.entries) {
      final lines = await SubtitleEffectOperations.generateSrtEffect(
        originalLine: source(caption), effect: entry.key,
        color: 'FFAA00', endDelay: .2,
      );
      expect(lines.length, greaterThanOrEqualTo(4), reason: entry.key);
      expect(lines.first.startTime, '00:00:01,000');
      expect(lines.last.endTime, '00:00:04,000');
      final groups = StudioDockEffectGroups.detect([
        for (final line in lines) StudioDockEffectFrame(
          id: line.index,
          start: line.startTime,
          end: line.endTime,
          original: line.original,
          edited: line.edited!,
        ),
      ]);
      expect(groups, hasLength(1), reason: entry.key);
      expect(groups.single.kind, entry.value, reason: entry.key);
      expect(groups.single.length, lines.length, reason: entry.key);
      expect(groups.single.previewText, caption, reason: entry.key);
    }
  });

  test('cursor animates grapheme clusters and disappears from last frame', () {
    const caption = 'കാ👩‍👩‍👧‍👦é';
    final frames = SrtEffectFrames.build(
      effect: 'typewriterCursor', text: caption, color: 'FFFFFF',
      availableMilliseconds: 3000,
    );
    expect(frames, hasLength(caption.characters.length));
    for (var i = 0; i < frames.length; i++) {
      final plain = frames[i].replaceAll(RegExp(r'<[^>]*>'), '');
      expect(plain, '${caption.characters.take(i + 1).join()}'
          '${i == frames.length - 1 ? '' : '▌'}');
    }
  });

  test('center reveal expands outwards without splitting graphemes', () {
    const caption = 'കാ👩‍👩‍👧‍👦éAB';
    final frames = SrtEffectFrames.build(
      effect: 'centerOutReveal', text: caption, color: 'FFFFFF',
      availableMilliseconds: 3000,
    );
    expect(frames, hasLength(caption.characters.length));
    expect(frames.last.replaceAll(RegExp(r'<[^>]*>'), ''), caption);
    for (final frame in frames) {
      final plain = frame.replaceAll(RegExp(r'<[^>]*>'), '');
      expect(caption.characters.toList().join().contains(plain), isTrue);
    }
  });

  test('blink alternates visible and blank timed frames', () {
    final frames = SrtEffectFrames.build(
      effect: 'blinkFlash', text: 'WARNING', color: 'FF0000',
      availableMilliseconds: 1500,
    );
    expect(frames.length.isOdd, isTrue);
    expect(frames.length, greaterThanOrEqualTo(5));
    for (var i = 0; i < frames.length; i++) {
      final visible = frames[i].replaceAll(RegExp(r'<[^>]*>'), '').trim();
      expect(visible, i.isEven ? 'WARNING' : '');
    }
  });

  test('rainbow colors complete graphemes and never changes their text', () {
    const content = 'കാ👩‍👩‍👧‍👦é';
    final frames = SrtEffectFrames.build(
      effect: 'rainbowText', text: content, color: 'FFFFFF',
      availableMilliseconds: 1500,
    );
    expect(frames, hasLength(7));
    for (final frame in frames) {
      expect(frame.replaceAll(RegExp(r'<[^>]*>'), ''), content);
      expect(RegExp(r'<font color=').allMatches(frame).length,
          content.characters.length);
    }
    expect(frames.toSet().length, frames.length);
  });

  test('scramble varies only unrevealed graphemes, then reveals all', () {
    const content = 'കാ👩‍👩‍👧‍👦é World';
    final glyphs = content.characters.toList(growable: false);
    final frames = SrtEffectFrames.build(
      effect: 'scrambleReveal', text: content, color: 'FFFFFF',
      availableMilliseconds: 2400,
    );
    expect(frames,
        hasLength(glyphs.where((glyph) => glyph.trim().isNotEmpty).length));
    for (var i = 0; i < frames.length; i++) {
      final visible = frames[i].replaceAll(RegExp(r'<[^>]*>'), '');
      final chars = visible.characters.toList(growable: false);
      expect(chars.length, glyphs.length);
      var revealed = 0;
      for (var k = 0; k < chars.length; k++) {
        if (glyphs[k].trim().isEmpty) {
          expect(chars[k], glyphs[k]);
        } else if (++revealed <= i + 1) {
          expect(chars[k], glyphs[k]);
        } else {
          expect(SrtEffectFrames.scrambleSymbols, contains(chars[k]));
        }
      }
    }
    expect(frames.last.replaceAll(RegExp(r'<[^>]*>'), ''), content);
    expect(frames.first, isNot(frames[1]));
  });

  test('invalid and too-short effects fail closed', () async {
    expect(SrtEffectFrames.build(effect: 'unsupported', text: 'Hello',
        color: 'FFFFFF', availableMilliseconds: 500), isEmpty);
    expect(SrtEffectFrames.build(effect: 'blinkFlash', text: 'Hi',
        color: 'FFFFFF', availableMilliseconds: 200), isEmpty);
    expect(SrtEffectFrames.build(effect: 'rainbowText', text: 'A',
        color: 'FFFFFF', availableMilliseconds: 2000), isEmpty);
    expect(SrtEffectFrames.build(effect: 'scrambleReveal', text: 'Hi',
        color: 'FFFFFF', availableMilliseconds: 2000), isEmpty);
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
