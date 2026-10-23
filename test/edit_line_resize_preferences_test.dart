import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/edit_line_controller.dart';

import 'support/test_isar_harness.dart';

Future<Preferences> _waitForSavedRatios(
  Isar isar, {
  required double desktop,
  required double mobile,
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 3)) {
    final preferences = await isar.preferences.where().findFirst();
    if (preferences != null &&
        preferences.editLineResizeRatio == desktop &&
        preferences.mobileVideoResizeRatio == mobile) {
      return preferences;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Edit Line pending ratios were not flushed on disposal');
}

void main() {
  test('Edit Line stores both final ratios when its provider is disposed',
      () async {
    final harness = await TestIsarHarness.open();
    try {
      final container = ProviderContainer(overrides: [
        isarProvider.overrideWithValue(harness.isar),
        editLineConfigurationProvider.overrideWithValue(
          const EditLineConfiguration(
            subtitleCollectionId: 1,
            lineIndex: 1,
            sessionId: 1,
          ),
        ),
      ]);

      final controller = container.read(editLineControllerProvider.notifier);
      controller.scheduleResizeRatio(0.42);
      controller.scheduleResizeRatio(0.61);
      controller.scheduleMobileVideoResizeRatio(0.53);
      controller.scheduleMobileVideoResizeRatio(0.68);

      final live = container.read(editLineControllerProvider);
      expect(live.resizeRatio, 0.61);
      expect(live.mobileVideoResizeRatio, 0.68);

      // The previous widget canceled both debounces here. The route-scoped
      // controller instead flushes the last values using captured writers.
      container.dispose();

      final saved = await _waitForSavedRatios(
        harness.isar,
        desktop: 0.61,
        mobile: 0.68,
      );
      expect(saved.editScreenResizeRatio, 0.35,
          reason: 'Edit Line must not overwrite the main Editor split ratio');
    } finally {
      await harness.close();
    }
  });

  test('rapid video-divider changes persist only the final ratios', () async {
    final harness = await TestIsarHarness.open();
    try {
      final container = ProviderContainer(overrides: [
        isarProvider.overrideWithValue(harness.isar),
        editLineConfigurationProvider.overrideWithValue(
          const EditLineConfiguration(
            subtitleCollectionId: 1,
            lineIndex: 1,
            sessionId: 1,
          ),
        ),
      ]);

      final controller = container.read(editLineControllerProvider.notifier);
      for (var i = 0; i < 1000; i++) {
        final fraction = i / 999;
        controller.scheduleResizeRatio(i == 999 ? 0.8 : 0.2 + 0.6 * fraction);
        controller.scheduleMobileVideoResizeRatio(
          i == 999 ? 0.2 : 0.8 - 0.6 * fraction,
        );
      }

      final live = container.read(editLineControllerProvider);
      expect(live.resizeRatio, closeTo(0.8, 0.000001));
      expect(live.mobileVideoResizeRatio, closeTo(0.2, 0.000001));

      // Pending debounced writes must retain the final value even when
      // the user closes Edit Line directly after a fast drag.
      container.dispose();
      final saved = await _waitForSavedRatios(
        harness.isar,
        desktop: 0.8,
        mobile: 0.2,
      );
      expect(saved.editScreenResizeRatio, 0.35);
    } finally {
      await harness.close();
    }
  });
}
