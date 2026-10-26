import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_effect_groups.dart';

StudioDockEffectFrame frame(int id, String edited,
    {String original = 'sample', String? start, String? end,
    String? effectiveText}) =>
    StudioDockEffectFrame(
      id: id,
      start: start ?? '00:00:0${id},000',
      end: end ?? '00:00:0${id + 1},000',
      original: original,
      edited: edited,
      effectiveText: effectiveText,
    );

void main() {
  group('effect group detection', () {
    test('recognizes adjacent progressive typewriter frames', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<font color="#ff00aa">കാ</font>', original: 'കാ!'),
        frame(2, '<font color="#ff00aa">കാ!</font>', original: 'കാ!'),
        frame(3, 'Unrelated', original: 'Other'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.typewriter);
      expect(groups.single.length, 2);
      expect(groups.single.firstId, 1);
      expect(groups.single.lastId, 2);
      expect(groups.single.contains(3), isFalse);
      expect(groups.single.previewText, 'കാ!');
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

    test('recognizes imported plain SRT text reveal without an edited column', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '', original: 'H'),
        frame(2, '', original: 'He'),
        frame(3, '', original: 'Hello'),
        frame(4, '', original: 'A separate sentence'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.typewriter);
      expect(groups.single.previewText, 'Hello');
      expect(groups.single.length, 3);
    });

    test('recognizes imported karaoke with moving highlight, mixed SRT tags '
        'and unquoted font colors', () {
      const source = 'Hello ലോകം again';
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<i><font color=#ffff00>Hello</font> ലോകം again</i>',
            original: source),
        frame(2, '<i>Hello <font color="#FFFF00">ലോകം</font> again</i>',
            original: source),
        frame(3, "<i>Hello ലോകം <font color='#ffff00'>again</font></i>",
            original: source),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.karaoke);
      expect(groups.single.previewText, source);
    });

    test('recognizes right-to-left reveal and backwards erase', () {
      final rightReveal = StudioDockEffectGroups.detect([
        frame(1, '', original: 'end'),
        frame(2, '', original: 'tend'),
        frame(3, '', original: 'attend'),
      ]);
      expect(rightReveal, hasLength(1));
      expect(rightReveal.single.kind, StudioDockEffectKind.reveal);

      final erase = StudioDockEffectGroups.detect([
        frame(1, '', original: 'Complete'),
        frame(2, '', original: 'Comple'),
        frame(3, '', original: 'Comp'),
      ]);
      expect(erase, hasLength(1));
      expect(erase.single.kind, StudioDockEffectKind.erase);
      expect(erase.single.previewText, 'Complete');
    });

    test('recognizes reveal one complete caption line at a time', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '', original: 'First line'),
        frame(2, '', original: 'First line\nരണ്ടാം വരി'),
        frame(3, '', original: 'First line\nരണ്ടാം വരി\nThird line'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.lineReveal);
    });

    test('a newline appearing mid-typewriter does not split the group', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '', original: 'H'),
        frame(2, '', original: 'He'),
        frame(3, '', original: 'He\nN'),
        frame(4, '', original: 'He\nNe'),
        frame(5, '', original: 'He\nNew'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.typewriter);
      expect(groups.single.length, 5);
    });

    test('recognizes timed color animation with equivalent SRT tags', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<b><font color="red">Alert</font></b>', original: 'Alert'),
        frame(2, '<b><font color=blue>Alert</font></b>', original: 'Alert'),
        frame(3, '<font color=red><b>Alert</b></font>', original: 'Alert'),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.kind, StudioDockEffectKind.colorAnimation);
    });

    test('recognizes repeated visible/blank blink frames, but not a pause', () {
      final blink = StudioDockEffectGroups.detect([
        frame(1, '', original: 'WARNING'),
        frame(2, '', original: ''),
        frame(3, '', original: 'WARNING'),
        frame(4, '', original: ''),
      ]);
      expect(blink, hasLength(1));
      expect(blink.single.kind, StudioDockEffectKind.blink);
      expect(blink.single.previewText, 'WARNING');

      expect(StudioDockEffectGroups.detect([
        frame(1, '', original: 'WARNING'),
        frame(2, '', original: ''),
        frame(3, '', original: 'WARNING'),
      ]), isEmpty);
    });

    test('handles SRT line breaks and dot-millisecond timestamps', () {
      final groups = StudioDockEffectGroups.detect([
        frame(1, '<font color="#ffee00">One</font><br>Two',
            original: 'One\nTwo', start: '00:00:01.000', end: '00:00:01.300'),
        frame(2, '<font color="#ffee00">One\nTwo</font>',
            original: 'One\nTwo', start: '00:00:01.301', end: '00:00:01.900'),
      ]);
      expect(groups.single.kind, StudioDockEffectKind.karaoke);
    });

    test('refuses two plain dialogue fragments and large or invalid gaps', () {
      expect(StudioDockEffectGroups.detect([
        frame(1, '', original: 'Thank'),
        frame(2, '', original: 'Thanks'),
      ]), isEmpty);
      expect(StudioDockEffectGroups.detect([
        frame(1, '', original: 'H'),
        frame(2, '', original: 'He', start: '00:00:05,000'),
        frame(3, '', original: 'Hey'),
      ]), isEmpty);
      expect(StudioDockEffectGroups.detect([
        frame(1, '', original: 'H', end: 'broken'),
        frame(2, '', original: 'He'),
        frame(3, '', original: 'Hey'),
      ]), isEmpty);
    });

    test('does not confuse incomplete Malayalam graphemes with frames', () {
      expect(StudioDockEffectGroups.detect([
        frame(1, '<font color="#ff00aa">ക</font>'),
        frame(2, '<font color="#ff00aa">കാ</font>'),
      ]), isEmpty);
    });

    test('respects an intentionally cleared edited text and unsupported tags', () {
      expect(StudioDockEffectGroups.detect([
        frame(1, '', original: 'H', effectiveText: ''),
        frame(2, '', original: 'He', effectiveText: ''),
        frame(3, '', original: 'Hey', effectiveText: ''),
      ]), isEmpty);
      expect(StudioDockEffectGroups.detect([
        frame(1, '<span>H</span>'),
        frame(2, '<span>He</span>'),
        frame(3, '<span>Hey</span>'),
      ]), isEmpty);
    });
  });
}
