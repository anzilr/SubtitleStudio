import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_time_range_planner.dart';

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  (Duration, Duration) plan({
    required int start,
    required int end,
    required WaveformTimeDrag drag,
    List<WaveformTimeBoundary> neighbors = const [],
    int playhead = 20000,
    bool overlap = false,
    bool magnet = true,
    int? originalStart,
  }) => WaveformTimeRangePlanner.constrain(
    start: ms(start),
    end: ms(end),
    playhead: ms(playhead),
    neighbors: neighbors,
    drag: drag,
    allowOverlap: overlap,
    magnetSnapEnabled: magnet,
    originalStart: originalStart == null ? null : ms(originalStart),
  );

  test('start handle snaps to a preceding end plus 25ms gap', () {
    final result = plan(
      start: 2040, end: 3000,
      drag: WaveformTimeDrag.startHandle,
      neighbors: [WaveformTimeBoundary(ms(1000), ms(2000))],
    );
    expect(result, (ms(2025), ms(3000)));
  });

  test('nearby following cue start cannot jump start handle to its far end',
      () {
    final result = plan(
      start: 4950, end: 4990,
      drag: WaveformTimeDrag.startHandle,
      neighbors: [WaveformTimeBoundary(ms(5000), ms(10000))],
    );
    expect(result, (ms(4950), ms(4990)));
  });

  test('end handle snaps to following start minus 25ms and keeps start', () {
    final result = plan(
      start: 4000, end: 4960,
      drag: WaveformTimeDrag.endHandle,
      neighbors: [WaveformTimeBoundary(ms(5000), ms(6000))],
    );
    expect(result, (ms(4000), ms(4975)));
  });

  test('playhead snap cannot reintroduce forbidden overlap', () {
    final result = plan(
      start: 2030, end: 3000,
      drag: WaveformTimeDrag.startHandle,
      playhead: 1990,
      neighbors: [WaveformTimeBoundary(ms(1000), ms(2000))],
    );
    expect(result, (ms(2025), ms(3000)));
  });

  test('dragging one handle past the other keeps its anchor and positive span',
      () {
    expect(plan(
      start: 5000, end: 4000,
      drag: WaveformTimeDrag.startHandle,
      magnet: false,
    ), (ms(3999), ms(4000)));
    expect(plan(
      start: 2000, end: 1000,
      drag: WaveformTimeDrag.endHandle,
      magnet: false,
    ), (ms(2000), ms(2001)));
    expect(plan(
      start: -500, end: 1000,
      drag: WaveformTimeDrag.startHandle,
      magnet: false,
    ), (Duration.zero, ms(1000)));
  });

  test('moving an overlay stops before its neighbor without shrinking', () {
    final neighbors = [WaveformTimeBoundary(ms(6000), ms(8000))];
    expect(plan(
      start: 4500, end: 6500,
      originalStart: 3000,
      drag: WaveformTimeDrag.move,
      neighbors: neighbors,
      magnet: false,
    ), (ms(4000), ms(6000)));
    expect(plan(
      start: 9000, end: 11000,
      originalStart: 3000,
      drag: WaveformTimeDrag.move,
      neighbors: neighbors,
      magnet: false,
    ), (ms(4000), ms(6000)),
      reason: 'One large pointer update must not jump over a subtitle');
  });

  test('moving backward stops at previous cue end, preserving length', () {
    final result = plan(
      start: 6500, end: 8500,
      originalStart: 9000,
      drag: WaveformTimeDrag.move,
      neighbors: [WaveformTimeBoundary(ms(5000), ms(7000))],
      magnet: false,
    );
    expect(result, (ms(7000), ms(9000)));
  });

  test('magnet on a moving overlay shifts both ends and retains safe gap', () {
    final result = plan(
      start: 4500, end: 6500,
      originalStart: 3000,
      drag: WaveformTimeDrag.move,
      neighbors: [WaveformTimeBoundary(ms(6000), ms(8000))],
    );
    expect(result, (ms(3975), ms(5975)));
  });

  test('overlap toggle permits intersection but never invalid duration', () {
    final neighbors = [WaveformTimeBoundary(ms(5000), ms(7000))];
    expect(plan(
      start: 4500, end: 6500,
      originalStart: 3000,
      drag: WaveformTimeDrag.move,
      neighbors: neighbors,
      overlap: true,
      magnet: false,
    ), (ms(4500), ms(6500)));
    expect(plan(
      start: 7000, end: 3000,
      drag: WaveformTimeDrag.startHandle,
      overlap: true,
      magnet: false,
    ), (ms(2999), ms(3000)));
  });
}
