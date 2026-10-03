import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Destructive application-maintenance operations.
///
/// Kept outside UI code so Settings never reaches the global database helper
/// directly. Dictionary data is intentionally preserved.
class AppDataMaintenanceRepository {
  final Isar _isar;

  const AppDataMaintenanceRepository(this._isar);

  Future<void> clearAllApplicationData() async {
    await logInfo(
      'Starting complete data wipe',
      context: 'AppDataMaintenanceRepository.clearAllApplicationData',
    );

    try {
      await _isar.writeTxn(() async {
        await _isar.preferences.clear();
        await _isar.sessions.clear();
        await _isar.subtitleCollections.clear();
        await _isar.checkpoints.clear();
        await _isar.videoPreferences.clear();
        await _isar.tutorialStatus.clear();
      });

      await _deleteWaveformCache();
      await _deleteTemporaryFiles();

      await logInfo(
        'Data wipe completed successfully',
        context: 'AppDataMaintenanceRepository.clearAllApplicationData',
      );
    } catch (e, stackTrace) {
      await logError(
        'Application data wipe failed',
        error: e,
        stackTrace: stackTrace,
        context: 'AppDataMaintenanceRepository.clearAllApplicationData',
      );
      rethrow;
    }
  }

  Future<void> _deleteWaveformCache() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final waveformDir = Directory('${appDocDir.path}/waveforms');
      if (await waveformDir.exists()) {
        await waveformDir.delete(recursive: true);
      }
    } catch (e, stackTrace) {
      await logWarning(
        'Could not fully clear waveform cache: $e',
        stackTrace: stackTrace,
        context: 'AppDataMaintenanceRepository._deleteWaveformCache',
      );
    }
  }

  Future<void> _deleteTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) return;

      await for (final entity in tempDir.list()) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (e, stackTrace) {
          await logWarning(
            'Could not delete a temporary entry: $e',
            stackTrace: stackTrace,
            context: 'AppDataMaintenanceRepository._deleteTemporaryFiles',
          );
        }
      }
    } catch (e, stackTrace) {
      await logWarning(
        'Could not fully clear temporary files: $e',
        stackTrace: stackTrace,
        context: 'AppDataMaintenanceRepository._deleteTemporaryFiles',
      );
    }
  }
}
