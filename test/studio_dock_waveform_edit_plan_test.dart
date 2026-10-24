import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_waveform_edit_plan.dart';

void main() {
  test('waveform durations have canonical SRT milliseconds', () {
    expect(StudioDockWaveformEditPlan.formatTime(Duration.zero),
        '00:00:00,000');
    expect(StudioDockWaveformEditPlan.formatTime(
        const Duration(hours: 2, minutes: 3, seconds: 4, milliseconds: 5)),
        '02:03:04,005');
    expect(StudioDockWaveformEditPlan.formatTime(
        const Duration(hours: 23, minutes: 59, seconds: 59,
            milliseconds: 999)), '23:59:59,999');
    expect(StudioDockWaveformEditPlan.formatTime(
        const Duration(milliseconds: -1)), isNull);
    expect(StudioDockWaveformEditPlan.formatTime(const Duration(days: 1)),
        isNull);
  });

  test('insertion order matches the mobile waveform add behavior', () {
    const starts = ['00:00:01,000', '00:00:03,000', '00:00:03,000',
      '00:00:08,000'];
    expect(StudioDockWaveformEditPlan.insertionPosition(
        starts, const Duration(milliseconds: 500)), 0);
    expect(StudioDockWaveformEditPlan.insertionPosition(
        starts, const Duration(seconds: 2)), 1);
    expect(StudioDockWaveformEditPlan.insertionPosition(
        starts, const Duration(seconds: 3)), 3);
    expect(StudioDockWaveformEditPlan.insertionPosition(
        starts, const Duration(seconds: 9)), 4);
    expect(StudioDockWaveformEditPlan.insertionPosition(
        const [], Duration.zero), 0);
  });
}
