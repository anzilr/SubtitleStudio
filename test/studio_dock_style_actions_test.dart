import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_style_actions.dart';

void main() {
  test('nine-grid alignment reuses supported SRT positioning tags', () {
    const original = 'Hello\nworld';
    expect(StudioDockStyleActions.alignment(original), 2);
    final topRight = StudioDockStyleActions.setAlignment(original, 9);
    expect(topRight, r'{\an9}Hello' '\nworld');
    expect(StudioDockStyleActions.alignment(topRight), 9);
    expect(StudioDockStyleActions.setAlignment(topRight, 1),
        r'{\an1}Hello' '\nworld');
    expect(() => StudioDockStyleActions.setAlignment(original, 0),
        throwsRangeError);
  });

  test('bold toggling preserves positioning and internal blank lines', () {
    const source = '{\\an8}  First\n\nSecond  ';
    final bold = StudioDockStyleActions.toggleTag(source, 'b');
    expect(bold, '{\\an8}  <b>First\n\nSecond</b>  ');
    expect(StudioDockStyleActions.toggleTag(bold, 'b'), source);
    expect(StudioDockStyleActions.alignment(bold), 8);
  });

  test('italic/underline reuse shared tags; clear keeps unrelated content', () {
    var text = StudioDockStyleActions.toggleTag('A', 'i');
    expect(text, '<i>A</i>');
    text = StudioDockStyleActions.toggleTag(text, 'u');
    expect(text, '<u><i>A</i></u>');
    expect(StudioDockStyleActions.clearSupportedTags(
        '{\\an7}<font color="#ABCD12">$text</font> [SFX]'), 'A [SFX]');
    expect(() => StudioDockStyleActions.toggleTag('x', 'script'),
        throwsArgumentError);
  });
}
