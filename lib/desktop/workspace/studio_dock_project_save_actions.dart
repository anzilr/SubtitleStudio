import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/desktop/workspace/studio_dock_file_actions.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';
import 'package:subtitle_studio/screens/edit/services/editor_export_service.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/project_file_service.dart';
import 'package:subtitle_studio/services/project_save_coordinator.dart';

/// The immutable .msone snapshot prepared before opening a native Save dialog.
/// It contains the complete checkpoint graph and persistent history refs.
class StudioDockPreparedProject {
  const StudioDockPreparedProject({
    required this.sessionId,
    required this.collectionId,
    required this.expectedProjectPath,
    required this.createdAt,
    required this.fileName,
    required this.encodedDocument,
  });

  final int sessionId;
  final int collectionId;
  final String? expectedProjectPath;
  final DateTime createdAt;
  final String fileName;
  final String encodedDocument;
}

/// Studio Dock's UI-free project persistence bridge. The existing coordinator
/// remains the only authority for .msone contents; the established desktop
/// export writer supplies explicit overwrite policy and file-system checks.
class StudioDockProjectSaveActions {
  StudioDockProjectSaveActions(
    this._projects,
    this._subtitles,
    this._coordinator, {
    EditorExportService? writer,
  }) : _writer = writer ?? EditorExportService();

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;
  final ProjectSaveCoordinator _coordinator;
  final EditorExportService _writer;

  Future<({Session session, SubtitleCollection collection})?> _owned(
    int sessionId,
    int collectionId,
  ) async {
    final session = await _projects.getSession(sessionId);
    if (session == null || session.subtitleCollectionId != collectionId) {
      return null;
    }
    final collection = await _subtitles.fetchSubtitleCollection(collectionId);
    if (collection == null) return null;
    return (session: session, collection: collection);
  }

  Future<StudioDockPreparedProject?> prepare({
    required int sessionId,
    required int collectionId,
  }) async {
    final owned = await _owned(sessionId, collectionId);
    if (owned == null) return null;
    // Keep this timestamp fixed for optimistic comparisons; the project
    // builder otherwise produces a fresh createdAt/lastSaved on each call.
    final createdAt = DateTime.now().toUtc();
    final document = await _coordinator.buildDocument(
      session: owned.session,
      subtitleCollection: owned.collection,
      now: createdAt,
    );
    return StudioDockPreparedProject(
      sessionId: sessionId,
      collectionId: collectionId,
      expectedProjectPath: owned.session.projectFilePath,
      createdAt: createdAt,
      fileName: _coordinator.suggestedProjectFileName(owned.session),
      encodedDocument: ProjectDocumentCodec.encode(document),
    );
  }

  /// A change to cues, notes, project metadata, checkpoints, or refs while a
  /// picker is open invalidates the prepared project instead of exporting a
  /// stale history graph as if it were the latest session.
  Future<bool> _stillCurrent(StudioDockPreparedProject prepared) async {
    final owned = await _owned(prepared.sessionId, prepared.collectionId);
    if (owned == null ||
        owned.session.projectFilePath != prepared.expectedProjectPath) {
      return false;
    }
    try {
      final current = await _coordinator.buildDocument(
        session: owned.session,
        subtitleCollection: owned.collection,
        now: prepared.createdAt,
      );
      return ProjectDocumentCodec.encode(current) == prepared.encodedDocument;
    } on StateError {
      // A concurrent checkpoint/reference edit may temporarily make the
      // builder reject a stale combination. Never write that combination.
      return false;
    }
  }

  Future<StudioDockFileResult> saveExisting({
    required int sessionId,
    required int collectionId,
  }) async {
    final prepared = await prepare(
      sessionId: sessionId, collectionId: collectionId);
    if (prepared == null) return StudioDockFileResult.failed;
    final path = prepared.expectedProjectPath;
    if (path == null || path.trim().isEmpty) {
      return StudioDockFileResult.needsLocation;
    }
    if (!await _stillCurrent(prepared)) return StudioDockFileResult.stale;
    final saved = await ProjectFileService.updateExistingProject(
      content: prepared.encodedDocument, projectFilePath: path);
    return saved ? StudioDockFileResult.saved
        : StudioDockFileResult.needsLocation;
  }

  Future<StudioDockFileResult> writeToPath({
    required StudioDockPreparedProject prepared,
    required String selectedPath,
    bool replaceExisting = false,
  }) async {
    final pickedFile = File(selectedPath);
    if (selectedPath.trim().isEmpty || !pickedFile.isAbsolute ||
        !selectedPath.toLowerCase().endsWith('.msone')) {
      return StudioDockFileResult.failed;
    }
    if (!await _stillCurrent(prepared)) return StudioDockFileResult.stale;

    // This is a UTF-8 JSON document, not an SRT encoded with the subtitle
    // charset. The existing writer treats the byte plan opaquely.
    final plan = EditorExportPlan(
      fileName: pickedFile.uri.pathSegments.last,
      bytes: Uint8List.fromList(utf8.encode(prepared.encodedDocument)),
    );
    final outcome = await _writer.writeDesktop(
      folder: pickedFile.parent.path,
      plan: plan,
      replaceExisting: replaceExisting,
    );
    if (outcome == EditorExportWriteResult.alreadyExists) {
      return StudioDockFileResult.alreadyExists;
    }

    // Once bytes are written, never point this live session to an older
    // document if the checkpoint graph moved while the disk operation ran.
    if (!await _stillCurrent(prepared)) {
      return StudioDockFileResult.savedButUnlinked;
    }
    final linked = await _projects.updateSessionProjectPathIfUnchanged(
      sessionId: prepared.sessionId,
      collectionId: prepared.collectionId,
      expectedProjectFilePath: prepared.expectedProjectPath,
      projectFilePath: selectedPath,
    );
    return linked ? StudioDockFileResult.saved
        : StudioDockFileResult.savedButUnlinked;
  }
}
