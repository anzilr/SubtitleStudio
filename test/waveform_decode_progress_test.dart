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

  test('waveform loader fill uses measured decoded time then zoom progress', () {
    const unknown = WaveformLoading('unknown',
      processedAudioTime: Duration(seconds: 35),
    );
    expect(unknown.extractedFraction, isNull);
    expect(unknown.waveformFillFraction, isNull,
        reason: 'A total cannot be invented for SAF/unknown durations');

    const decoding = WaveformLoading('known',
      progress: 0.1,
      processedAudioTime: Duration(seconds: 25),
      totalAudioTime: Duration(seconds: 100),
    );
    expect(decoding.extractedFraction, 0.25);
    expect(decoding.waveformFillFraction, closeTo(0.2125, 0.0001));

    const overflowing = WaveformLoading('known',
      processedAudioTime: Duration(seconds: 120),
      totalAudioTime: Duration(seconds: 100),
    );
    expect(overflowing.extractedFraction, 1.0);
    expect(overflowing.waveformFillFraction, 0.85);

    const building = WaveformLoading('known', progress: 0.65);
    expect(building.waveformFillFraction, greaterThan(0.85));
    expect(building.waveformFillFraction, lessThan(1));
    const complete = WaveformLoading('known', progress: 1.0);
    expect(complete.waveformFillFraction, 1.0);
  });

  test('new extraction gets independent processed-media timeline', () {
    final old = WaveformDecodeProgress();
    final next = WaveformDecodeProgress();
    expect(old.accept(119000), const Duration(seconds: 119));
    expect(next.accept(1200), const Duration(milliseconds: 1200));
  });
}
