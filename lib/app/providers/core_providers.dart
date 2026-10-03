import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/repositories/app_preferences_repository.dart';
import 'package:subtitle_studio/app/repositories/app_data_maintenance_repository.dart';
import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/services/tutorial_preferences_repository.dart';
import 'package:subtitle_studio/features/import_comments/project_comment_repository.dart';

/// Root database dependency for Riverpod-managed code.
///
/// The Isar instance is initialized during application bootstrap and injected
/// through the root ProviderScope. New Riverpod-managed repositories should
/// depend on this provider instead of importing main.dart to access a global
/// database variable.
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
  return CheckpointRepository(ref.watch(isarProvider));
});


final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(isarProvider));
});



final projectCommentRepositoryProvider =
    Provider<ProjectCommentRepository>((ref) {
  return ProjectCommentRepository(ref.watch(isarProvider));
});

final subtitleImportRepositoryProvider =
    Provider<SubtitleImportRepository>((ref) {
  return SubtitleImportRepository(ref.watch(isarProvider));
});

final tutorialPreferencesRepositoryProvider =
    Provider<TutorialPreferencesRepository>((ref) {
  return TutorialPreferencesRepository(ref.watch(isarProvider));
});
