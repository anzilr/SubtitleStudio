import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_decode_progress.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';

void main() {
  test('statistics are throttled, monotonic and protected against invalid values',
      () {
    final gate = WaveformDecodeProgress();
    expect(gate.accept(0), isNull);
    expect(gate.accept(-1), isNull);
    expect(gate.accept(double.nan), isNull);
    expect(gate.accept(double.infinity), isNull);
    expect(gate.accept(1000), const Duration(seconds: 1));
    expect(gate.accept(2500), isNull);
    expect(gate.accept(3000), const Duration(seconds: 3));
    expect(gate.accept(2000), isNull);
    expect(gate.accept(5000), const Duration(seconds: 5));
    expect(gate.accept(864000001), isNull);
    gate.close();
    expect(gate.accept(12000), isNull,
        reason: 'Late native statistics must not re-enter WaveformLoading');
  });

  test('processed media time is not presented as percent complete', () {
    expect(WaveformDecodeProgress.format(const Duration(seconds: 5)),
        'Audio processed: 0:00:05');
    expect(WaveformDecodeProgress.format(const Duration(
      hours: 2, minutes: 4, seconds: 19,
    )), 'Audio processed: 2:04:19');
    const loading = WaveformLoading('source', processedAudioTime:
        Duration(hours: 1));
    expect(loading.progress, 0);
    expect(loading.processedAudioTime, const Duration(hours: 1));
    expect(loading.props, contains(const Duration(hours: 1)));
  });

  test('new extraction gets independent processed-media timeline', () {
    final old = WaveformDecodeProgress();
    final next = WaveformDecodeProgress();
    expect(old.accept(119000), const Duration(seconds: 119));
    expect(next.accept(1200), const Duration(milliseconds: 1200));
  });
}
