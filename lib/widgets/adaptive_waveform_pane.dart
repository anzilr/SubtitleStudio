import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps the video and waveform inside the height assigned by a mobile split.
///
/// Previously the waveform always requested 180 logical pixels even when a
/// persisted splitter ratio left less than 181 pixels for the entire pane.
class AdaptiveWaveformPane extends StatelessWidget {
  const AdaptiveWaveformPane({
    super.key,
    required this.video,
    required this.waveform,
    required this.showWaveform,
  });

  final Widget video;
  final Widget waveform;
  final bool showWaveform;

  static const double preferredWaveformHeight = 180;
  static const double minimumVideoHeight = 120;
  static const double minimumWaveformHeight = 80;
  static const double dividerHeight = 1;

  static const double minimumPreferredPaneHeight =
      minimumVideoHeight + preferredWaveformHeight + dividerHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final availableForWaveform = height - minimumVideoHeight - dividerHeight;
        final canShowWaveform = showWaveform &&
            height.isFinite &&
            availableForWaveform >= minimumWaveformHeight;

        if (!canShowWaveform) {
          // A very short viewport must never create a zero-height video
          // player or allow a fixed waveform to overflow its container.
          return SizedBox.expand(child: video);
        }

        final waveformHeight =
            math.min(preferredWaveformHeight, availableForWaveform);
        return Column(
          children: [
            Expanded(child: video),
            const Divider(height: dividerHeight),
            SizedBox(height: waveformHeight, child: waveform),
          ],
        );
      },
    );
  }
}
