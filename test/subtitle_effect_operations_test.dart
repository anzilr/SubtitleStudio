import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_groups.dart';
import 'package:subtitle_studio/operations/subtitle_effect_operations.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/utils/time_parser.dart';

SubtitleLine _line(int index, String text) {
  return SubtitleLine()
    ..index = index
    ..startTime = '00:00:0$index,000'
    ..endTime = '00:00:0$index,900'
    ..original = text
    ..edited = null
    ..marked = false
    ..comment = null
    ..resolved = false;
}

void main() {
  group('mobile effect generation shared with Studio Dock', () {
    test('generated Malayalam effects round-trip through SRT recognition',
        () async {
      const content = 'നമസ്കാരം  ലോകം\nസുഖമാണോ';
      final original = _line(1, content);
      for (final type in ['karaoke', 'typewriter']) {
        final generated = type == 'karaoke'
            ? await SubtitleEffectOperations.generateKaraokeEffect(
                originalLine: original, color: 'ffee11')
            : await SubtitleEffectOperations.generateTypewriterEffect(
                originalLine: original, color: 'ffee11');
        final before = [for (final line in generated) line.edited];
        final groups = StudioDockEffectGroups.detect([
          for (final line in generated) StudioDockEffectFrame(
            id: line.index,
            start: line.startTime,
            end: line.endTime,
            original: line.original,
            edited: line.edited ?? '',
          ),
        ]);
        expect(groups, hasLength(1), reason: type);
        expect(groups.single.kind, type == 'karaoke'
            ? StudioDockEffectKind.karaoke
            : StudioDockEffectKind.typewriter);
        expect(groups.single.length, generated.length);
        expect([for (final line in generated) line.edited], before,
            reason: 'Recognition must not modify exported subtitle content');
      }
    });

    test('typewriter creates progressive frames with bounded timestamps',
        () async {
      final source = _line(1, 'AB');
      final output = await SubtitleEffectOperations.generateTypewriterEffect(
        originalLine: source, color: 'ff00cc', endDelay: .1,
      );
      expect(output, hasLength(2));
      expect(output.first.edited, '<font color="#ff00cc">A</font>');
      expect(output.last.edited, '<font color="#ff00cc">AB</font>');
      expect(output.first.original, source.original);
      expect(parseTimeString(output.first.startTime).inMilliseconds, 1000);
      expect(parseTimeString(output.last.endTime).inMilliseconds, 1900);
      expect(parseTimeString(output.first.endTime).inMilliseconds,
          lessThanOrEqualTo(
              parseTimeString(output.last.startTime).inMilliseconds));
    });

    test('karaoke word highlight progresses across the full cue', () async {
      final source = _line(2, 'one two three')..marked = true;
      final output = await SubtitleEffectOperations.generateKaraokeEffect(
        originalLine: source, color: 'ffee00', effectType: 'word',
      );
      expect(output, hasLength(3));
      expect(output.first.edited, contains('<font color="#ffee00">one</font>'));
      expect(output.last.edited,
          '<font color="#ffee00">one two three</font>');
      expect(output.every((line) => line.marked), isTrue);
      expect(output.map((line) => line.index), [2, 3, 4]);
      expect(parseTimeString(output.first.startTime).inMilliseconds, 2000);
      expect(parseTimeString(output.last.endTime).inMilliseconds, 2900);
    });

    test('karaoke supports character granularity and selected span', () async {
      final source = _line(3, 'A BC Z');
      final output = await SubtitleEffectOperations.generateKaraokeEffect(
        originalLine: source, color: '00ff00',
        effectType: 'character', hasTextSelection: true,
        selectionStart: 2, selectionEnd: 4,
        selectedText: 'BC', fullText: 'A BC Z',
      );
      expect(output, hasLength(2));
      expect(output.first.edited, 'A <font color="#00ff00">B</font>C Z');
      expect(output.last.edited, 'A <font color="#00ff00">BC</font> Z');
      expect(parseTimeString(output.last.endTime).inMilliseconds, 3900);
    });

    test('Malayalam conjuncts and emoji animate as complete visible glyphs',
        () async {
      const content = 'കേൾക്കാം 👩‍👩‍👧‍👦';
      final source = _line(1, content);
      final clusters = content.characters.toList();
      final typewriter = await SubtitleEffectOperations.generateTypewriterEffect(
          originalLine: source, color: 'ffcc00');
      expect(typewriter.length, clusters.length);
      for (var i = 0; i < typewriter.length; i++) {
        expect(typewriter[i].edited,
            '<font color="#ffcc00">${clusters.take(i + 1).join()}</font>');
      }
      final karaoke = await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: source, color: 'ffcc00', effectType: 'character');
      expect(karaoke.length, clusters.length);
      expect(karaoke.last.edited, '<font color="#ffcc00">$content</font>');
    });

    test('word karaoke preserves multilingual whitespace and newlines', () async {
      const content = 'നമസ്കാരം  ലോകം\nസുഖമാണോ';
      final frames = await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: _line(2, content), color: 'ffaa00');
      expect(frames, hasLength(3));
      expect(frames.first.edited,
          '<font color="#ffaa00">നമസ്കാരം</font>  ലോകം\nസുഖമാണോ');
      expect(frames[1].edited,
          '<font color="#ffaa00">നമസ്കാരം  ലോകം</font>\nസുഖമാണോ');
      expect(frames.last.edited, '<font color="#ffaa00">$content</font>');
    });

    test('selected complex-script span is expanded to glyph boundaries', () async {
      const content = 'A കാ B';
      final frames = await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: _line(3, content), color: 'aabbcc',
          effectType: 'character', hasTextSelection: true,
          fullText: content, selectedText: 'ാ',
          selectionStart: 3, selectionEnd: 4);
      expect(frames, hasLength(1));
      expect(frames.single.edited, 'A <font color="#aabbcc">കാ</font> B');
    });

    test('long text is paced rather than flashing a frame per code point',
        () async {
      final longText = List.filled(120, 'കാ').join();
      final frames = await SubtitleEffectOperations.generateTypewriterEffect(
          originalLine: _line(4, longText), color: 'fff000');
      expect(frames.length, lessThanOrEqualTo(15));
      expect(frames.last.edited, '<font color="#fff000">$longText</font>');
      expect(parseTimeString(frames.last.endTime).inMilliseconds, 4900);
      for (final frame in frames) {
        expect(parseTimeString(frame.startTime).inMilliseconds,
            lessThan(parseTimeString(frame.endTime).inMilliseconds));
      }
    });

    test('blank text and exhausted animation duration do not generate lines',
        () async {
      final empty = _line(4, '  ');
      final source = _line(4, 'Some text');
      expect(await SubtitleEffectOperations.generateTypewriterEffect(
          originalLine: empty, color: 'ffffff'), isEmpty);
      expect(await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: empty, color: 'ffffff'), isEmpty);
      expect(await SubtitleEffectOperations.generateTypewriterEffect(
          originalLine: source, color: 'ffffff', endDelay: .9), isEmpty);
      expect(await SubtitleEffectOperations.generateKaraokeEffect(
          originalLine: source, color: 'ffffff', endDelay: 1), isEmpty);
    });
  });

  group('SubtitleEffectOperations.buildEffectDeltas', () {
    test('replaces one line with generated effect lines when replayed', () {
      final before = [
        _line(1, 'A'),
        _line(2, 'B'),
        _line(3, 'C'),
      ];
      final effectLines = [
        _line(2, 'B1'),
        _line(3, 'B2'),
        _line(4, 'B3'),
      ];

      final deltas = SubtitleEffectOperations.buildEffectDeltas(
        originalLine: before[1],
        originalLineIndex: 1,
        effectLines: effectLines,
      );

      expect(deltas, hasLength(4));
      expect(deltas.first.changeType, 'delete');
      expect(deltas.first.lineIndex, 1);
      expect(deltas.first.beforeState?.original, 'B');

      final restored = CheckpointStateReducer.copyLines(before);
      CheckpointStateReducer.applyDeltasInPlace(restored, deltas);

      expect(
        restored.map((line) => line.original).toList(),
        ['A', 'B1', 'B2', 'B3', 'C'],
      );
    });

    test('copies delta states instead of retaining mutable line references', () {
      final original = _line(1, 'Original');
      final effect = _line(1, 'Effect');

      final deltas = SubtitleEffectOperations.buildEffectDeltas(
        originalLine: original,
        originalLineIndex: 0,
        effectLines: [effect],
      );

      original.original = 'Mutated original';
      effect.original = 'Mutated effect';

      expect(deltas.first.beforeState?.original, 'Original');
      expect(deltas.last.afterState?.original, 'Effect');
    });
  });
}
