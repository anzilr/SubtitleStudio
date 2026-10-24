import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/services/editor_direct_save_service.dart';
import 'package:subtitle_studio/screens/edit/services/editor_export_service.dart';
import 'package:subtitle_studio/screens/edit_line/services/edit_line_file_save_service.dart';
import 'package:subtitle_studio/services/checkpoint_state_reducer.dart';
import 'package:subtitle_studio/utils/macos_bookmark_manager.dart';

enum StudioDockFileResult {
  saved,
  canceled,
  needsLocation,
  alreadyExists,
  stale,
  savedButUnlinked,
  invalidEncoding,
  failed,
}

/// Immutable byte plan captured *before* a potentially long system dialog.
/// Save As rechecks it against fresh Isar state before writing any bytes.
class StudioDockPreparedFile {
  StudioDockPreparedFile({
    required this.sessionId,
    required this.collectionId,
    required this.fileName,
    required this.encoding,
    required this.filePath,
    required this.originalFileUri,
    required this.macOsBookmark,
    required this.lines,
    required this.plan,
    required this.relinkAfterSave,
  });

  final int sessionId;
  final int collectionId;
  final String fileName;
  final String encoding;
  final String? filePath;
  final String? originalFileUri;
  final String? macOsBookmark;
  final List<SubtitleLine> lines;
  final EditorExportPlan plan;
  final bool relinkAfterSave;
}

/// Non-UI desktop save/export boundary. It reuses mobile's charset-aware SRT
/// compiler, the Editor direct-save bookmark policy, and the existing desktop
/// exporter (including explicit overwrite checks). No history or subtitle
/// mutations are made just to export a file.
class StudioDockFileActions {
  StudioDockFileActions(
    this._projects,
    this._subtitles, {
    EditorDirectSaveService? directSave,
    EditLineFileSaveService? fileSave,
    EditorExportService? exporter,
    Future<Uint8List?> Function(String)? createBookmark,
    bool? isMacOS,
  })  : _directSave = directSave ?? EditorDirectSaveService(),
        _fileSave = fileSave ?? EditLineFileSaveService(),
        _exporter = exporter ?? EditorExportService(),
        _createBookmark = createBookmark ?? MacOSBookmarkManager.createBookmark,
        _isMacOS = isMacOS ?? Platform.isMacOS;

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;
  final EditorDirectSaveService _directSave;
  final EditLineFileSaveService _fileSave;
  final EditorExportService _exporter;
  final Future<Uint8List?> Function(String) _createBookmark;
  final bool _isMacOS;

  Future<SubtitleCollection?> _ownedCollection(
    int sessionId, int collectionId,
  ) async {
    final session = await _projects.getSession(sessionId);
    if (session == null || session.subtitleCollectionId != collectionId) {
      return null;
    }
    return _subtitles.fetchSubtitleCollection(collectionId);
  }

  Future<StudioDockFileResult> saveExisting({
    required int sessionId,
    required int collectionId,
  }) async {
    final collection = await _ownedCollection(sessionId, collectionId);
    if (collection == null) return StudioDockFileResult.failed;
    // EditorDirectSaveService validates the charset *before* trying the
    // original URI, bookmark or legacy path. Never write a lossy fallback.
    final result = await _directSave.save(collection, collection.lines);
    if (!result.saved) return StudioDockFileResult.needsLocation;
    final legacyPath = result.legacyFilePathToPersist;
    if (legacyPath != null && legacyPath.isNotEmpty) {
      final updated = await _subtitles.updateOriginalFileUri(
        collectionId: collectionId, originalFileUri: legacyPath);
      if (!updated) return StudioDockFileResult.savedButUnlinked;
    }
    return StudioDockFileResult.saved;
  }

  Future<StudioDockPreparedFile?> prepareSaveAs({
    required int sessionId,
    required int collectionId,
  }) async {
    final collection = await _ownedCollection(sessionId, collectionId);
    if (collection == null) return null;
    final bytes = await _fileSave.prepareBytes(collection, collection.lines);
    final name = collection.fileName.toLowerCase().endsWith('.srt')
        ? collection.fileName : '${collection.fileName}.srt';
    return _prepare(collection, sessionId,
      EditorExportPlan(fileName: name, bytes: bytes), relink: true);
  }

  Future<StudioDockPreparedFile?> prepareExport({
    required int sessionId,
    required int collectionId,
    required bool originalOnly,
  }) async {
    final collection = await _ownedCollection(sessionId, collectionId);
    if (collection == null) return null;
    final plan = await _exporter.prepare(
      lines: collection.lines,
      encoding: collection.encoding,
      requestedName: collection.fileName,
      customTag: 'MSone',
      originalOnly: originalOnly,
    );
    return _prepare(collection, sessionId, plan, relink: false);
  }

  StudioDockPreparedFile _prepare(
    SubtitleCollection collection,
    int sessionId,
    EditorExportPlan plan, {
    required bool relink,
  }) => StudioDockPreparedFile(
    sessionId: sessionId,
    collectionId: collection.id,
    fileName: collection.fileName,
    encoding: collection.encoding,
    filePath: collection.filePath,
    originalFileUri: collection.originalFileUri,
    macOsBookmark: collection.macOsSrtBookmark,
    lines: CheckpointStateReducer.copyLines(collection.lines),
    plan: plan,
    relinkAfterSave: relink,
  );

  Future<bool> _stillCurrent(StudioDockPreparedFile prepared) async {
    final current = await _ownedCollection(
      prepared.sessionId, prepared.collectionId);
    if (current == null || current.encoding != prepared.encoding ||
        current.fileName != prepared.fileName ||
        current.filePath != prepared.filePath ||
        current.originalFileUri != prepared.originalFileUri ||
        current.macOsSrtBookmark != prepared.macOsBookmark ||
        current.lines.length != prepared.lines.length) return false;
    for (var i = 0; i < current.lines.length; i++) {
      if (!CheckpointStateReducer.samePersistedLine(
          current.lines[i], prepared.lines[i])) return false;
    }
    return true;
  }

  /// The native picker supplies a destination path without writing bytes.
  /// The caller must explicitly confirm replacement after alreadyExists.
  Future<StudioDockFileResult> writeToPath({
    required StudioDockPreparedFile prepared,
    required String selectedPath,
    bool replaceExisting = false,
  }) async {
    final path = selectedPath;
    if (path.trim().isEmpty || !File(path).isAbsolute ||
        !path.toLowerCase().endsWith('.srt')) {
      return StudioDockFileResult.failed;
    }
    if (!await _stillCurrent(prepared)) return StudioDockFileResult.stale;

    // Let the existing writer verify the output folder and reject accidental
    // replacement. Do not infer permission from an existing source locator.
    final pickedFile = File(path);
    final plan = prepared.plan.renamed(
      pickedFile.uri.pathSegments.last);
    final outcome = await _exporter.writeDesktop(
      folder: pickedFile.parent.path,
      plan: plan,
      replaceExisting: replaceExisting,
    );
    if (outcome == EditorExportWriteResult.alreadyExists) {
      return StudioDockFileResult.alreadyExists;
    }
    if (!prepared.relinkAfterSave) return StudioDockFileResult.saved;
    // A concurrent change during disk I/O cannot be rolled back safely, but
    // it must not attach that older byte snapshot as the project's new source.
    if (!await _stillCurrent(prepared)) {
      return StudioDockFileResult.savedButUnlinked;
    }

    String? encodedBookmark;
    if (_isMacOS) {
      // Store only a fresh security-scoped bookmark for the new SRT. A stale
      // bookmark for the previous file must never authorize future saves.
      final bookmark = await _createBookmark(path);
      if (bookmark == null || bookmark.isEmpty) {
        return StudioDockFileResult.savedButUnlinked;
      }
      encodedBookmark = base64Encode(bookmark);
    }
    final linked = await _subtitles.updateSaveLocationIfUnchanged(
      collectionId: prepared.collectionId,
      sessionId: prepared.sessionId,
      expectedFilePath: prepared.filePath,
      expectedOriginalFileUri: prepared.originalFileUri,
      expectedMacOsBookmark: prepared.macOsBookmark,
      filePath: path,
      originalFileUri: path,
      macOsBookmark: encodedBookmark,
    );
    return linked ? StudioDockFileResult.saved
        : StudioDockFileResult.savedButUnlinked;
  }
}
