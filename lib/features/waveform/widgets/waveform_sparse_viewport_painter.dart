import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_progressive_viewport.dart';

/// Read-only R11 demonstration of spatially positioned, sparse decoded audio.
///
/// No pointer handlers; unknown pixels are hatched, never drawn as silence.
class WaveformSparseViewportPainter extends CustomPainter {
  const WaveformSparseViewportPainter({
    required this.viewport,
    required this.waveColor,
    required this.unknownColor,
    this.onPaint,
  });

  final WaveformProgressiveViewport viewport;
  final Color waveColor;
  final Color unknownColor;
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final spans = viewport.project(size.width);
    final knownPaint = Paint()
      ..color = waveColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final backgroundPaint = Paint()
      ..color = unknownColor.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill;
    final hatchPaint = Paint()
      ..color = unknownColor.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final boundaryPaint = Paint()
      ..color = unknownColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;
    final center = size.height / 2;
    final scale = size.height * 0.46;

    for (final span in spans) {
      if (span.endPixel <= span.startPixel) continue;
      if (!span.isKnown) {
        canvas.drawRect(
          Rect.fromLTRB(span.startPixel, 0, span.endPixel, size.height),
          backgroundPaint,
        );
        // Hatching conveys unknown availability, rather than 0-amplitude.
        for (double x = span.startPixel - size.height;
             x < span.endPixel; x += 14.0) {
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(
              span.startPixel, 0, span.endPixel, size.height));
          canvas.drawLine(Offset(x, size.height),
              Offset(x + size.height, 0), hatchPaint);
          canvas.restore();
        }
        continue;
      }
      final left = math.max(0, span.startPixel.ceil());
      final right = math.min(size.width.ceil(), span.endPixel.ceil());
      for (var x = left; x < right; x++) {
        final peaks = span.signedPeaksAt(x + 0.5);
        if (peaks == null) continue;
        final (low, high) = peaks;
        canvas.drawLine(
          Offset(x.toDouble(), center - high * scale),
          Offset(x.toDouble(), center - low * scale),
          knownPaint,
        );
      }
      canvas.drawLine(Offset(span.startPixel, 0),
          Offset(span.startPixel, size.height), boundaryPaint);
      canvas.drawLine(Offset(span.endPixel, 0),
          Offset(span.endPixel, size.height), boundaryPaint);
    }
    onPaint?.call();
  }

  @override
  bool shouldRepaint(covariant WaveformSparseViewportPainter oldDelegate) =>
      !identical(viewport, oldDelegate.viewport) ||
      waveColor != oldDelegate.waveColor ||
      unknownColor != oldDelegate.unknownColor;
}
