import 'package:flutter/material.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_preview.dart';

/// Debug-only R10 display, with NO seek, selection or editing hit regions.
class WaveformWindowPreviewPainter extends CustomPainter {
  const WaveformWindowPreviewPainter({
    required this.preview,
    required this.color,
    this.onPaint,
  });

  final WaveformWindowPreview preview;
  final Color color;
  /// Fires only after drawing at a positive, nonempty canvas size.
  /// Used for debug-only, device-observable R10 paint verification.
  final VoidCallback? onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 ||
        preview.minima.isEmpty) return;
    final baseline = size.height / 2;
    final amplitude = size.height * 0.46;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final count = preview.minima.length;
    for (var x = 0; x < size.width.ceil(); x++) {
      final index = (x * count / size.width).floor().clamp(0, count - 1);
      final top = baseline - preview.maxima[index] * amplitude;
      final bottom = baseline - preview.minima[index] * amplitude;
      canvas.drawLine(Offset(x.toDouble(), top),
          Offset(x.toDouble(), bottom), paint);
    }
    onPaint?.call();
  }

  @override
  bool shouldRepaint(covariant WaveformWindowPreviewPainter oldDelegate) =>
      !identical(preview, oldDelegate.preview) || color != oldDelegate.color;
}
