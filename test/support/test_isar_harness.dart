import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Reusable isolated Isar instance for persistence integration tests.
///
/// Every harness gets a unique database name and temporary directory so tests
/// cannot accidentally share state. All production collection schemas are
/// opened to keep integration tests aligned with the real application schema.
class TestIsarHarness {
  static int _nextInstanceId = 0;

  final Directory directory;
  final Isar isar;

  TestIsarHarness._({
    required this.directory,
    required this.isar,
  });

  static Future<TestIsarHarness> open() async {
    final directory = await Directory.systemTemp.createTemp(
      'subtitle_studio_isar_test_',
    );
    final instanceId = _nextInstanceId++;

    try {
      final isar = await Isar.open(
        [
          PreferencesSchema,
          SessionSchema,
          SubtitleCollectionSchema,
          DictionaryEntrySchema,
          CheckpointSchema,
          VideoPreferencesSchema,
          TutorialStatusSchema,
        ],
        directory: directory.path,
        name:
            'subtitle_studio_test_'
            '${DateTime.now().microsecondsSinceEpoch}_'
            '$instanceId',
      );

      return TestIsarHarness._(
        directory: directory,
        isar: isar,
      );
    } catch (_) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> close() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
