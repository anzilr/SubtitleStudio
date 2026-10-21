import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/edit/services/editor_secondary_subtitle_service.dart';

SubtitleLine line(int index, String original) => SubtitleLine()
  ..index = index
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = original;

void main() {
  group('Editor secondary subtitle source', () {
    test('blank original cues remain present with their indices and timing', () {
      final source = [line(1, ''), line(2, 'Line one<br>Line two'), line(3, ' ')];

      final projected = EditorSecondarySubtitleService.fromOriginal(source);

      expect(projected, hasLength(3));
      expect(projected.map((item) => item.index), [1, 2, 3]);
      expect(projected.first.text, '');
      expect(projected.first.startTime, '00:00:01,000');
      expect(projected[1].text, 'Line one\nLine two');
      expect(projected.last.text, ' ');
      expect(() => projected.clear(), throwsUnsupportedError);
    });

    test('refresh rebuilds an original-text track even while hidden', () {
      const state = EditState(
        secondarySubtitleSource: EditorSecondarySubtitleSource.originalText,
        showSecondarySubtitles: false,
      );

      final refreshed = EditorSecondarySubtitleService.refreshedOriginal(
        source: state.secondarySubtitleSource,
        primaryLines: [line(1, 'Changed'), line(2, '')],
      );

      expect(refreshed!.map((cue) => cue.text), ['Changed', '']);
      expect(state.showSecondarySubtitles, isFalse);
    });

    test('an external track never refreshes from a matching first cue', () {
      final primaryLines = [line(1, 'Same'), line(2, 'Changed')];

      final refreshed = EditorSecondarySubtitleService.refreshedOriginal(
        source: EditorSecondarySubtitleSource.external,
        primaryLines: primaryLines,
      );

      expect(refreshed, isNull);
    });

    test('an unset secondary source does not synthesize a track', () {
      expect(
        EditorSecondarySubtitleService.refreshedOriginal(
          source: EditorSecondarySubtitleSource.none,
          primaryLines: [line(1, 'Primary only')],
        ),
        isNull,
      );
    });

    test('state copies retain source independent from visibility', () {
      const state = EditState(
        secondarySubtitleSource: EditorSecondarySubtitleSource.external,
        showSecondarySubtitles: true,
      );

      final hidden = state.copyWith(showSecondarySubtitles: false);
      expect(hidden.secondarySubtitleSource,
          EditorSecondarySubtitleSource.external);

      final changed = hidden.copyWith(
        secondarySubtitleSource: EditorSecondarySubtitleSource.originalText,
      );
      expect(changed.secondarySubtitleSource,
          EditorSecondarySubtitleSource.originalText);
      expect(changed.showSecondarySubtitles, isFalse);
      expect(changed, isNot(hidden));
    });
  });
}
