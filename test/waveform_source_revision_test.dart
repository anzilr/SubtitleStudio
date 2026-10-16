import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_source_revision.dart';

void main() {
  test('SAF metadata requires positive size and modified timestamp', () {
    expect(WaveformSourceRevision.fromMetadata(
      {'size': 1000, 'modified': 23000}), 'size=1000;modified=23000');
    for (final value in <Map<Object?, Object?>?>[
      null,
      {},
      {'size': 0, 'modified': 100},
      {'size': 30, 'modified': 0},
      {'size': 30, 'modified': null},
      {'size': '30', 'modified': 10},
    ]) {
      expect(WaveformSourceRevision.fromMetadata(value), isNull);
    }
  });
}
