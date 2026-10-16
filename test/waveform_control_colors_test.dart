import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_control_colors.dart';

void main() {
  test('restored waveform controls retain distinct semantic action colors', () {
    expect(WaveformControlColors.zoom, Colors.orange);
    expect(WaveformControlColors.overlap, Colors.orange);
    expect(WaveformControlColors.magnet, Colors.red);
    expect(WaveformControlColors.addLine, const Color(0xFF00695C));
    expect(WaveformControlColors.confirm, Colors.green);
    expect(WaveformControlColors.cancel, Colors.red);
    expect(WaveformControlColors.autoScroll, Colors.blue);
    expect({
      WaveformControlColors.zoom,
      WaveformControlColors.magnet,
      WaveformControlColors.addLine,
      WaveformControlColors.confirm,
      WaveformControlColors.autoScroll,
    }.length, 5);
  });
}
