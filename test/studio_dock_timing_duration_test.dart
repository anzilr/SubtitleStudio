import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_timing_edit_service.dart';

void main() {
  test('Duration maps valid seconds to an exact end millisecond', () {
    expect(StudioDockTimingEditService.endFromDuration(
        '00:00:01,000', '2.5').endMilliseconds, 3500);
    expect(StudioDockTimingEditService.endFromDuration(
        '00:00:01,999', '0.001').endMilliseconds, 2000);
    expect(StudioDockTimingEditService.endFromDuration(
        '00:00:01,000', '2.125').endMilliseconds, 3125);
  });

  test('Invalid duration is rejected without inventing an end time', () {
    for (final value in ['', '0', '-1', 'NaN', '2.1234', '1e3']) {
      final result = StudioDockTimingEditService.endFromDuration(
          '00:00:01,000', value);
      expect(result.endMilliseconds, isNull, reason: value);
      expect(result.error, isNotNull, reason: value);
    }
  });

  test('Invalid start and day overflow cannot produce a persisted end', () {
    final badStart = StudioDockTimingEditService.endFromDuration(
        'invalid', '1.500');
    expect(badStart.endMilliseconds, isNull);
    expect(badStart.error, contains('START'));
    final overflow = StudioDockTimingEditService.endFromDuration(
        '23:59:59,000', '2');
    expect(overflow.endMilliseconds, isNull);
    expect(overflow.error, contains('END'));
    expect(StudioDockTimingEditService.endFromDuration(
        '23:59:59,000', '0.999').endMilliseconds, 86399999);
  });
}
