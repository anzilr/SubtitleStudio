import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_file_save_service.dart';
import 'package:subtitle_studio/utils/macos_bookmark_manager.dart';

/// Platform-scoped bookmark access. The real adapter pairs resolution with
/// stopAccessing; tests can exercise the same finally policy on any host.
abstract class EditorBookmarkAccess {
  Future<String?> resolve(Uint8List bookmark);
  Future<void> release(String nativePath);
}

final class DeviceEditorBookmarkAccess implements EditorBookmarkAccess {
  const DeviceEditorBookmarkAccess();

  @override
  Future<String?> resolve(Uint8List bookmark) =>
      MacOSBookmarkManager.resolveBookmark(bookmark);

  @override
  Future<void> release(String nativePath) =>
      MacOSBookmarkManager.stopAccessingSecurityScopedResource(nativePath);
}

/// The Editor owns feedback/Save As UI, but not byte conversions, document
/// locators or macOS bookmark lifecycles. A failed direct write returns
/// `saved == false` and allows the caller's existing Save As interaction.
final class EditorDirectSaveResult {
  const EditorDirectSaveResult({
    required this.saved,
    this.legacyFilePathToPersist,
  });

  final bool saved;

  /// Only set when an older collection had no original URI and its native
  /// filePath write succeeded. The caller may migrate that identity through
  /// its normal session-aware repository, without mutating a stale Isar copy.
  final String? legacyFilePathToPersist;
}

final editorDirectSaveServiceProvider = Provider<EditorDirectSaveService>(
  (ref) => EditorDirectSaveService(),
);

final class EditorDirectSaveService {
  EditorDirectSaveService({
    EditLineFileSaveService? saver,
    EditorBookmarkAccess? bookmarks,
    bool? isMacOS,
  })  : _saver = saver ?? EditLineFileSaveService(),
        _bookmarks = bookmarks ?? const DeviceEditorBookmarkAccess(),
        _isMacOS = isMacOS ?? Platform.isMacOS;

  final EditLineFileSaveService _saver;
  final EditorBookmarkAccess _bookmarks;
  final bool _isMacOS;

  Future<EditorDirectSaveResult> save(
    SubtitleCollection collection,
    List<SubtitleLine> lines,
  ) async {
    // Validate BEFORE any path, bookmark, permission or write interaction.
    // An unsupported charset must never truncate a user's existing file.
    final bytes = await _saver.prepareBytes(collection, lines);

    // Old .msone packages can still contain non-SRT source links. They must
    // never authorize the SRT compiler to overwrite VTT/ASS/SSA originals.
    final source = collection.originalFileUri?.trim().isNotEmpty == true
        ? collection.originalFileUri
        : collection.filePath;
    if (!_isSrtDocument(collection.fileName) ||
        source == null || !_isSafeSrtSource(source)) {
      return const EditorDirectSaveResult(saved: false);
    }

    if (_isMacOS) {
      // Keep the established macOS policy: only a currently resolvable
      // security-scoped SRT bookmark authorizes direct save. A path stored in
      // old project metadata is not a substitute for that grant.
      final encodedBookmark = collection.macOsSrtBookmark;
      if (encodedBookmark == null || encodedBookmark.isEmpty) {
        return const EditorDirectSaveResult(saved: false);
      }
      String? resolvedPath;
      try {
        resolvedPath = await _bookmarks.resolve(
          Uint8List.fromList(base64Decode(encodedBookmark)),
        );
        if (resolvedPath == null || resolvedPath.isEmpty) {
          return const EditorDirectSaveResult(saved: false);
        }
        if (!_isSrtDocument(resolvedPath)) {
          return const EditorDirectSaveResult(saved: false);
        }
        return EditorDirectSaveResult(
          saved: await _saver.writeExistingLocator(resolvedPath, bytes),
        );
      } on FormatException {
        // Invalid legacy bookmark metadata cannot authorize a file write.
        return const EditorDirectSaveResult(saved: false);
      } on FileSystemException {
        return const EditorDirectSaveResult(saved: false);
      } on Exception {
        // Bookmark providers can fail with platform-channel exceptions when
        // access is revoked. Keep the existing Save As recovery path.
        return const EditorDirectSaveResult(saved: false);
      } finally {
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          await _bookmarks.release(resolvedPath);
        }
      }
    }

    final saved = await _saver.saveExisting(collection, bytes);
    final original = collection.originalFileUri;
    final legacyPath = saved && (original == null || original.trim().isEmpty)
        ? collection.filePath
        : null;
    return EditorDirectSaveResult(
      saved: saved,
      legacyFilePathToPersist: legacyPath,
    );
  }

  static bool _isSrtDocument(String path) =>
      path.trim().toLowerCase().split('?').first.endsWith('.srt');

  static bool _isSafeSrtSource(String source) =>
      source.startsWith('content://') || _isSrtDocument(source);
}
