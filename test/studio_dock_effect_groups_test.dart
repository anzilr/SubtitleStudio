import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_groups.dart';

StudioDockEffectFrame frame(int id, String edited,
    {String original = 'sample', String? start, String? end}) =>
    StudioDockEffectFrame(
      id: id,
      start: start ?? '00:00:0${id},000',
      end: end ?? '00:00:0${id + 1},000',
      original: original,
      edited: edited,
    );

void main() {
  group('effect group detection', () {
    test('recognizes adjacent progressive typewriter frames', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<font color="#ff00aa">ക</font>', original: 'കാ'),
        frame(2, '<font color="#ff00aa">കാ</font>', original: 'കാ'),
        frame(3, 'Unrelated', original: 'Other'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.typewriter);
      expect(groups.single.length, 2);
      expect(groups.single.firstId, 1);
      expect(groups.single.lastId, 2);
      expect(groups.single.contains(3), isFalse);
    });

    test('recognizes karaoke while preserving Malayalam whitespace', () {
      const original = 'നമസ്കാരം  ലോകം\nസുഖമാണോ';
      final groups = StudioDockEffectGroups.detect([
        frame(1,
            '<font color="#ffee11">നമസ്കാരം</font>  ലോകം\nസുഖമാണോ',
            original: original),
        frame(2,
            '<font color="#ffee11">നമസ്കാരം  ലോകം</font>\nസുഖമാണോ',
            original: original),
        frame(3, '<font color="#ffee11">$original</font>',
            original: original),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.karaoke);
      expect(groups.single.length, 3);
    });

    test('recognizes karaoke applied to a selected substring', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, 'Before <font color="#ffaa00">മ</font>ലയാളം after'),
        frame(2, 'Before <font color="#ffaa00">മല</font>യാളം after'),
        frame(3, 'Before <font color="#ffaa00">മലയാളം</font> after'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.karaoke);
    });

    test('never folds ordinary, time-disjoint, or differently colored lines', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<font color="#ffffff">A</font>'),
        frame(2, '<font color="#000000">AB</font>'),
        frame(3, '<font color="#ffffff">ABC</font>', start: '00:00:08,000'),
        frame(4, 'Plain text'),
      ]);
      expect(groups, isEmpty);
    });

    test('separate consecutive effects form separate groups', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<font color="#ffffff">A</font>'),
        frame(2, '<font color="#ffffff">AB</font>'),
        frame(3, '<font color="#ffffff">A</font>'),
        frame(4, '<font color="#ffffff">AB</font>'),
      ]);
      expect(groups, hasLength(2));
      expect(groups.map((group) => group.firstId), [1, 3]);
    });
  });
}
