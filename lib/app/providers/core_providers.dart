import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/repositories/app_preferences_repository.dart';
import 'package:subtitle_studio/app/repositories/app_data_maintenance_repository.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';

/// Root database dependency for Riverpod-managed code.
///
/// The Isar instance is initialized during application bootstrap and injected
/// through the root ProviderScope. New Riverpod-managed repositories should
/// depend on this provider instead of importing main.dart to access a global
/// database variable.
///
/// During the incremental migration the legacy global [isar] variable remains
/// available for existing code. It will be removed only after all consumers
/// have moved behind injected repositories.
final isarProvider = Provider<Isar>((ref) {
  throw StateError(
    'isarProvider must be overridden with the initialized Isar instance '
    'at application bootstrap.',
  );
});

final appPreferencesRepositoryProvider =
    Provider<AppPreferencesRepository>((ref) {
  return AppPreferencesRepository(ref.watch(isarProvider));
});


final appDataMaintenanceRepositoryProvider =
    Provider<AppDataMaintenanceRepository>((ref) {
  return AppDataMaintenanceRepository(ref.watch(isarProvider));
});

final checkpointRepositoryProvider = Provider<CheckpointRepository>((ref) {
  return const CheckpointRepository();
});


final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(isarProvider));
});


final subtitleImportRepositoryProvider =
    Provider<SubtitleImportRepository>((ref) {
  return SubtitleImportRepository(ref.watch(isarProvider));
});
