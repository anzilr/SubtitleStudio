import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/repositories/app_preferences_repository.dart';

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
