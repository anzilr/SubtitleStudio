import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';

void main() {
  group('EditState.copyWith nullable fields', () {
    test('preserves nullable fields during unrelated updates', () {
      const state = EditState(
        errorMessage: 'problem',
        selectedVideoPath: '/video.mp4',
        highlightedIndex: 4,
        isRangeSelectionActive: true,
        rangeStartIndex: 2,
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.errorMessage, 'problem');
      expect(updated.selectedVideoPath, '/video.mp4');
      expect(updated.highlightedIndex, 4);
      expect(updated.rangeStartIndex, 2);
      expect(updated.isRangeSelectionActive, isTrue);
    });

    test('explicit clear flags clear nullable fields', () {
      const state = EditState(
        errorMessage: 'problem',
        selectedVideoPath: '/video.mp4',
        highlightedIndex: 4,
        rangeStartIndex: 2,
      );

      final updated = state.copyWith(
        clearErrorMessage: true,
        clearSelectedVideoPath: true,
        clearHighlightedIndex: true,
        clearRangeStartIndex: true,
      );

      expect(updated.errorMessage, isNull);
      expect(updated.selectedVideoPath, isNull);
      expect(updated.highlightedIndex, isNull);
      expect(updated.rangeStartIndex, isNull);
    });

    test('clearSelection clears range start without losing other nullable state', () {
      const state = EditState(
        selectedVideoPath: '/video.mp4',
        highlightedIndex: 7,
        isSelectionMode: true,
        selectedIndices: {1, 2},
        isRangeSelectionActive: true,
        rangeStartIndex: 1,
      );

      final updated = state.clearSelection();

      expect(updated.selectedVideoPath, '/video.mp4');
      expect(updated.highlightedIndex, 7);
      expect(updated.selectedIndices, isEmpty);
      expect(updated.isSelectionMode, isFalse);
      expect(updated.isRangeSelectionActive, isFalse);
      expect(updated.rangeStartIndex, isNull);
    });
  });
}
