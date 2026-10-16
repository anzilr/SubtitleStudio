import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/models/subtitle_entry.dart';
import 'package:subtitle_studio/screens/edit/services/raw_srt_document.dart';

void main() {
  test('raw SRT text remains a single document across multiple cues', () {
    final entries = <SubtitleEntry>[
      SubtitleEntry(
        index: '1',
        startTime: '00:00:01,000',
        endTime: '00:00:02,300',
        text: 'മലയാളം\nمرحبا',
      ),
      SubtitleEntry(
        index: '2',
        startTime: '00:00:04,000',
        endTime: '00:00:05,000',
        text: '<i>Subtitle</i>',
      ),
    ];
    final raw = RawSrtDocument.compose(entries);
    expect(raw, contains('1\n00:00:01,000 --> 00:00:02,300'));
    expect(raw, contains('\n\n2\n00:00:04,000'));
    final restored = RawSrtDocument.parseStrict(raw);
    expect(restored.map((entry) => entry.toSrtString()).toList(),
        entries.map((entry) => entry.toSrtString()).toList());
  });

  test('invalid partial cue never silently replaces valid persisted entries',
      () {
    expect(
      () => RawSrtDocument.parseStrict(
        '1\n00:00:01,000 -->\nUnfinished timing',
      ),
      throwsFormatException,
    );
    expect(() => RawSrtDocument.parseStrict('  '), throwsFormatException);
    final restored = RawSrtDocument.parseStrict(
      '\uFEFF1\r\n00:00:01,000 --> 00:00:03,000\r\nEdited text',
    );
    expect(restored.single.text, 'Edited text');
  });
}
