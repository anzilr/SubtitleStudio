import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A waveform-shaped loading indicator. The filled region reflects measured
/// audio timeline coverage when a source duration is known; with unknown
/// duration a moving highlight indicates activity without inventing percent.
class WaveformLoadingBars extends StatefulWidget {
  final double? fillFraction;
  final Color activeColor;
  final Color inactiveColor;

  const WaveformLoadingBars({
    super.key,
    required this.fillFraction,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<WaveformLoadingBars> createState() => _WaveformLoadingBarsState();
}

class _WaveformLoadingBarsState extends State<WaveformLoadingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.fillFraction == null) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveformLoadingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fillFraction == null && oldWidget.fillFraction != null) {
      _pulse.repeat();
    } else if (widget.fillFraction != null && oldWidget.fillFraction == null) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.fillFraction;
    return Semantics(
      label: progress == null
          ? 'Generating waveform, progress unknown'
          : 'Generating waveform',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: progress?.clamp(0.0, 1.0).toDouble() ?? 0.0,
        ),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, filled, _) => AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            painter: _WaveformLoadingPainter(
              fillFraction: progress == null ? null : filled,
              phase: _pulse.value,
              activeColor: widget.activeColor,
              inactiveColor: widget.inactiveColor,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WaveformLoadingPainter extends CustomPainter {
  final double? fillFraction;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;

  const _WaveformLoadingPainter({
    required this.fillFraction,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const bars = 51;
    const gap = 2.4;
    final width = (size.width - (bars - 1) * gap) / bars;
    if (width <= 0) return;

    final trackPaint = Paint()..color = inactiveColor;
    final fillPaint = Paint()..color = activeColor;
    final centerY = size.height / 2;

    // Deterministic, varied amplitudes evoke an actual audio waveform. These
    // are decorative bars, not fabricated audio samples from the source.
    final paths = <RRect>[];
    for (var i = 0; i < bars; i++) {
      final envelope = math.pow(
        math.sin(math.pi * (i + 2) / (bars + 4)), 0.6,
      ).toDouble();
      final detail = 0.28 + 0.72 * math.sin(i * 1.73).abs();
      final height = 4 + (size.height - 8) * envelope * detail;
      final left = i * (width + gap);
      final rect = Rect.fromLTWH(left, centerY - height / 2, width, height);
      final radius = Radius.circular(width / 2);
      final shape = RRect.fromRectAndRadius(rect, radius);
      paths.add(shape);
      canvas.drawRRect(shape, trackPaint);
    }

    if (fillFraction != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
        0, 0, size.width * fillFraction!.clamp(0.0, 1.0), size.height,
      ));
      for (final bar in paths) {
        canvas.drawRRect(bar, fillPaint);
      }
      canvas.restore();
    } else {
      // With unknown duration, sweep a small glow across the inactive bars
      // rather than suggesting a made-up processing percentage.
      for (var i = 0; i < bars; i++) {
        final normalized = i / (bars - 1);
        final distance = (normalized - phase).abs();
        final wrapped = math.min(distance, 1 - distance);
        final strength = (1 - wrapped / 0.19).clamp(0.0, 1.0);
        if (strength == 0) continue;
        fillPaint.color = activeColor.withValues(alpha: 0.2 + 0.8 * strength);
        canvas.drawRRect(paths[i], fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformLoadingPainter oldDelegate) =>
      oldDelegate.fillFraction != fillFraction ||
      (fillFraction == null && oldDelegate.phase != phase) ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
