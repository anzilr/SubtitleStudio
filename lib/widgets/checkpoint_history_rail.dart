import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:subtitle_studio/services/checkpoint_history_lane_layout.dart';

/// Compact, theme-aware visual tracks for the Git-inspired history list.
///
/// The graph is decorative; accessibility and checkout actions remain in
/// the adjacent text/card. Edges come exclusively from the validated parent
/// IDs, not timestamp proximity or list position.
class CheckpointHistoryRailPainter extends CustomPainter {
  final CheckpointHistoryLaneRow row;
  final int laneCount;
  final ColorScheme colors;

  const CheckpointHistoryRailPainter({
    required this.row,
    required this.laneCount,
    required this.colors,
  });

  static double railWidth(int laneCount) =>
      math.min(106.0, math.max(34.0, 28.0 + (laneCount - 1) * 19.0));

  @override
  void paint(Canvas canvas, Size size) {
    final columnCount = math.max(1, laneCount);
    final step = columnCount <= 1
        ? 0.0
        : math.min(19.0, (railWidth(columnCount) - 22.0) / (columnCount - 1));
    double x(int lane) => 13.0 + lane * step;
    final y = size.height / 2;
    final mainX = x(row.lane);
    final joining = row.joiningLanes.toSet();
    final above = row.tracksAbove.toSet();

    final muted = Paint()
      ..color = colors.outline
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final highlighted = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Continue unrelated tracks unchanged; only parent edges actually
    // converging at this checkpoint are allowed to bend into its dot.
    for (final lane in row.tracksAbove) {
      if (!joining.contains(lane)) {
        canvas.drawLine(Offset(x(lane), 0), Offset(x(lane), size.height), muted);
        continue;
      }
      final paint = row.node.isHeadAncestor ? highlighted : muted;
      if (lane == row.lane) {
        canvas.drawLine(Offset(mainX, 0), Offset(mainX, y), paint);
      } else {
        final path = Path()
          ..moveTo(x(lane), 0)
          ..lineTo(x(lane), y * .55)
          ..quadraticBezierTo(x(lane), y, mainX, y);
        canvas.drawPath(path, paint);
      }
    }

    for (final lane in row.tracksBelow) {
      if (lane == row.lane) {
        canvas.drawLine(
          Offset(mainX, y),
          Offset(mainX, size.height),
          row.node.isHeadAncestor ? highlighted : muted,
        );
      } else if (!above.contains(lane)) {
        canvas.drawLine(Offset(x(lane), y), Offset(x(lane), size.height), muted);
      }
    }

    final markerCenter = Offset(mainX, y);
    final active = row.node.isHead;
    final markerRadius = active ? 7.0 : 5.5;
    canvas.drawCircle(
      markerCenter, markerRadius + 2,
      Paint()..color = colors.surface,
    );
    canvas.drawCircle(
      markerCenter, markerRadius,
      Paint()
        ..color = active ? colors.primary : colors.surface
        ..strokeWidth = 2.2
        ..style = active ? PaintingStyle.fill : PaintingStyle.stroke,
    );
    if (!active) {
      canvas.drawCircle(
        markerCenter, markerRadius,
        Paint()
          ..color = row.node.isHeadAncestor ? colors.primary : colors.outline
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
    } else {
      canvas.drawCircle(
        markerCenter, 2.5,
        Paint()..color = colors.onPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CheckpointHistoryRailPainter oldDelegate) =>
      oldDelegate.row != row ||
      oldDelegate.laneCount != laneCount ||
      oldDelegate.colors != colors;
}
