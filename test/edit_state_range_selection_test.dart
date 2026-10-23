import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';

void main() {
  group('EditState range selection', () {
    test('range start survives unrelated state updates', () {
      const state = EditState(
        isRangeSelectionActive: true,
        rangeStartIndex: 3,
      );

      final updated = state.copyWith(isLoading: true);

      expect(updated.isRangeSelectionActive, isTrue);
      expect(updated.rangeStartIndex, 3);
    });

    test('range start can be explicitly cleared', () {
      const state = EditState(
        isRangeSelectionActive: true,
        rangeStartIndex: 3,
      );

      final updated = state.copyWith(
        isRangeSelectionActive: false,
        clearRangeStartIndex: true,
      );

      expect(updated.isRangeSelectionActive, isFalse);
      expect(updated.rangeStartIndex, isNull);
    });
  });
}
