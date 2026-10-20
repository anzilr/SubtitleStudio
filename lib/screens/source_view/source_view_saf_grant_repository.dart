import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';

/// Stored SAF locators are *metadata*, not live Android permissions.
///
/// Keep the legacy 'saf_uri_<filePath>' preference key intact so old projects
/// continue to resolve their previously selected documents.
final sourceViewSafGrantRepositoryProvider =
    Provider<SourceViewSafGrantRepository>(
  (ref) => SourceViewSafGrantRepositoryImpl(),
);

abstract class SourceViewSafGrantRepository {
  Future<String?> resolve({
    required String filePath,
    String? providedUri,
  });
}

/// Injectable preference operations make permission-metadata migration
/// testable without Android platform code or a global SharedPreferences mock.
abstract class SourceViewSafGrantStore {
  Future<String?> read(String key);
  Future<void> write(String key, String uri);
  Future<void> remove(String key);
}

final class SharedPreferencesSafGrantStore implements SourceViewSafGrantStore {
  const SharedPreferencesSafGrantStore();

  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, uri);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// Chooses a validated SAF locator without allowing stale persisted metadata
/// to redirect an explicitly opened document to an unrelated document.
///
/// A valid caller-provided grant takes precedence and updates the old key.
/// Without an explicit grant, only a validated legacy value is reused. If a
/// saved value is invalid or mismatched, it is discarded; direct Android
/// document paths still resolve to *their own* locator.
final class SourceViewSafGrantRepositoryImpl
    implements SourceViewSafGrantRepository {
  SourceViewSafGrantRepositoryImpl({SourceViewSafGrantStore? store})
      : _store = store ?? const SharedPreferencesSafGrantStore();

  final SourceViewSafGrantStore _store;

  static String legacyKey(String filePath) => 'saf_uri_$filePath';

  @override
  Future<String?> resolve({
    required String filePath,
    String? providedUri,
  }) async {
    final source = SourceViewFileTarget.resolve(filePath: filePath);
    final supplied = providedUri?.trim();

    // Treat an explicitly supplied document as the current user selection.
    // Validate before changing any persistent state.
    if (supplied != null && supplied.isNotEmpty) {
      SourceViewFileTarget.resolve(filePath: filePath, safUri: supplied);
      await _store.write(legacyKey(filePath), supplied);
      return supplied;
    }

    final stored = await _store.read(legacyKey(filePath));
    if (stored != null) {
      try {
        final validated = SourceViewFileTarget.resolve(
          filePath: filePath,
          safUri: stored,
        );
        if (validated.androidDocumentUri != null &&
            validated.androidDocumentUri == stored) {
          return stored;
        }
      } on FormatException {
        // A stale, malformed or cross-document key must never be used.
      }
      // Retain the old key name while removing unusable metadata. Do not
      // log the source path, URI, display name or document ID.
      await _store.remove(legacyKey(filePath));
    }

    // A direct content:// source is its own document even without a separate
    // saved SAF locator. Actual read/write permission is checked on IO.
    return source.androidDocumentUri;
  }
}
