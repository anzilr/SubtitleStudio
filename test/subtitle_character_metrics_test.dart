import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_character_metrics.dart';

void main() {
  test('counts only displayed text using the mobile Edit Line convention', () {
    final metrics = SubtitleCharacterMetrics.measure(
      'One<br><b>Two</b>{\\an8}!',
      maxLineLength: 3,
    );
    expect(metrics.count, 8); // One\nTwo!
    expect(metrics.hasLongLine, isTrue); // The second row is 4 characters.
  });

  test('user line limit applies per line, not to the whole subtitle', () {
    final metrics = SubtitleCharacterMetrics.measure(
      'Four\nFive', maxLineLength: 4,
    );
    expect(metrics.count, 9);
    expect(metrics.hasLongLine, isFalse);
    expect(SubtitleCharacterMetrics.measure('Five', maxLineLength: 3)
        .hasLongLine, isTrue);
  });

  test('empty text and tags alone are not long', () {
    expect(SubtitleCharacterMetrics.measure('').count, 0);
    final metrics = SubtitleCharacterMetrics.measure('<i>{\\an1}</i>');
    expect(metrics.count, 0);
    expect(metrics.hasLongLine, isFalse);
  });
}
