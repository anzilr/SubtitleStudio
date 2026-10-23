import 'package:flutter/material.dart';

/// Presentation-only sizing for the compact portrait Edit Line pilot.
/// Editing controllers, scroll positions and media ownership stay with their
/// existing widgets. Tablet, landscape and desktop dimensions are unchanged.
class EditLinePortraitMetrics {
  const EditLinePortraitMetrics({
    required this.isCompactPortrait,
    required this.contentPadding,
    required this.videoHeight,
    required this.originalCueHeight,
    required this.editedCueHeight,
  });

  final bool isCompactPortrait;
  final double contentPadding;
  final double videoHeight;
  final double originalCueHeight;
  final double editedCueHeight;

  factory EditLinePortraitMetrics.fromSize(Size size) {
    final compact = size.width <= 430 && size.height > size.width;
    return EditLinePortraitMetrics(
      isCompactPortrait: compact,
      contentPadding: compact ? 10 : 16,
      videoHeight: compact
          ? (size.height * 0.26).clamp(170.0, 200.0).toDouble()
          : 240,
      // Reference text needs less space than the actively edited subtitle.
      originalCueHeight: compact ? 76 : 100,
      editedCueHeight: compact ? 120 : 100,
    );
  }

  factory EditLinePortraitMetrics.of(BuildContext context) =>
      EditLinePortraitMetrics.fromSize(MediaQuery.sizeOf(context));
}

/// Retains the original Start/End Time fields side by side on all sizes.
/// The caller owns both field controllers and validation state.
class EditLineTimeFieldsLayout extends StatelessWidget {
  const EditLineTimeFieldsLayout({
    super.key,
    required this.startField,
    required this.endField,
  });

  final Widget startField;
  final Widget endField;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('edit-line-time-side-by-side'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: startField),
      const SizedBox(width: 16),
      Expanded(child: endField),
    ],
  );
}
