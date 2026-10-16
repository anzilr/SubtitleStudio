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
    expect(WaveformControlColors.subtitleOverlay, const Color(0xFFFF9800));
    expect(WaveformControlColors.editBars,
        WaveformControlColors.subtitleOverlay);
    expect(WaveformControlColors.subtitleOverlay,
        isNot(WaveformControlColors.waveform(ThemeData.dark())));
    expect(WaveformControlColors.subtitleOverlay,
        isNot(WaveformControlColors.addLine));
    expect({
      WaveformControlColors.zoom,
      WaveformControlColors.magnet,
      WaveformControlColors.addLine,
      WaveformControlColors.confirm,
      WaveformControlColors.autoScroll,
    }.length, 5);
  });
}
