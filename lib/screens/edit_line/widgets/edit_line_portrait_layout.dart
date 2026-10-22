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
    required this.sectionGap,
  });

  final bool isCompactPortrait;
  final double contentPadding;
  final double videoHeight;
  final double originalCueHeight;
  final double editedCueHeight;
  final double sectionGap;

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
      sectionGap: compact ? 8 : 16,
    );
  }

  factory EditLinePortraitMetrics.of(BuildContext context) =>
      EditLinePortraitMetrics.fromSize(MediaQuery.sizeOf(context));
}

/// Full timestamps remain readable on small phones rather than being forced
/// into two very narrow columns. Both fields retain the caller's controllers.
class EditLineTimeFieldsLayout extends StatelessWidget {
  const EditLineTimeFieldsLayout({
    super.key,
    required this.startField,
    required this.endField,
  });

  final Widget startField;
  final Widget endField;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 380) {
        return Column(
          key: const ValueKey('edit-line-time-stacked'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            startField,
            const SizedBox(height: 8),
            endField,
          ],
        );
      }
      return Row(
        key: const ValueKey('edit-line-time-side-by-side'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: startField),
          const SizedBox(width: 16),
          Expanded(child: endField),
        ],
      );
    },
  );
}
