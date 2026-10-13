import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/checkpoint_head_reference.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_import_plan.dart';
import 'package:subtitle_studio/widgets/session_selection/project_history_reference_import_plan.dart';
import 'package:subtitle_studio/services/checkpoint_reference_migration_plan.dart';

final sessionProjectImportRepositoryProvider =
    Provider<SessionProjectImportRepository>((ref) {
  return SessionProjectImportRepository(ref.watch(isarProvider));
});

class SessionProjectImportRepository {
  final Isar _isar;

  const SessionProjectImportRepository(this._isar);

  Future<List<Session>> fetchSessions() {
    return _isar.sessions.where().findAll();
  }

  Future<SubtitleCollection?> getSubtitleCollection(int collectionId) {
    return _isar.subtitleCollections.get(collectionId);
  }

  Future<Session> replaceSession({
    required Session session,
    required ProjectDocument projectDocument,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
    bool importSubtitlesOnly = false,
  }) async {
    // Validate before any write: an invalid history cannot partially
    // overwrite an existing session or destroy its previous checkpoints.
    final history = importSubtitlesOnly
        ? null
        : PreparedProjectHistory.build(
            projectDocument.checkpoints,
            toSubtitleLine: _toSubtitleLine,
          );
    final referencePlan = importSubtitlesOnly
        ? null
        : ProjectHistoryReferenceImportPlan.prepare(
            data: projectDocument.historyReferences,
            history: history,
          );
    final subtitleData = projectDocument.subtitleCollection;
    final subtitleLines = _parseSubtitleLines(subtitleData.lines);

    late Session updatedSession;
    await _isar.writeTxn(() async {
      final currentSession = await _isar.sessions.get(session.id);
      if (currentSession == null) {
        throw StateError('Session was deleted during project replacement.');
      }
      final collection = await _isar.subtitleCollections
          .get(currentSession.subtitleCollectionId);
      if (collection == null) {
        throw StateError('Session subtitle collection not found.');
      }

      _applySubtitleFileSelection(
        collection: collection,
        subtitleData: subtitleData,
        srtFileInfo: srtFileInfo,
      );
      collection.encoding = subtitleData.encoding;
      collection.lines = subtitleLines;
      _applySessionSelection(
        session: currentSession,
        subtitleData: subtitleData,
        sessionData: projectDocument.session,
        srtFileInfo: srtFileInfo,
        originalProjectUri: originalProjectUri,
      );

      // Old history describes the old working tree and must not be mixed with
      // the imported graph. Deletion and replacement share one transaction.
      final oldCheckpoints = await _isar.checkpoints
          .filter()
          .sessionIdEqualTo(currentSession.id)
          .findAll();
      if (oldCheckpoints.isNotEmpty) {
        await _isar.checkpoints.deleteAll(
          oldCheckpoints.map((checkpoint) => checkpoint.id).toList(),
        );
      }
      await _isar.subtitleCollections.put(collection);
      await _isar.sessions.put(currentSession);
      await _persistCheckpointsInTransaction(
        sessionId: currentSession.id,
        subtitleCollectionId: currentSession.subtitleCollectionId,
        history: history,
        referencePlan: referencePlan,
      );
      updatedSession = currentSession;
    });

    return updatedSession;
  }

  Future<Session> importAsNewSession({
    required ProjectDocument projectDocument,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
    bool importSubtitlesOnly = false,
  }) async {
    final history = importSubtitlesOnly
        ? null
        : PreparedProjectHistory.build(
            projectDocument.checkpoints,
            toSubtitleLine: _toSubtitleLine,
          );
    final sessionData = projectDocument.session;
    final referencePlan = importSubtitlesOnly
        ? null
        : ProjectHistoryReferenceImportPlan.prepare(
            data: projectDocument.historyReferences,
            history: history,
          );
    final subtitleData = projectDocument.subtitleCollection;
    final subtitleLines = _parseSubtitleLines(subtitleData.lines);

    final fileSelection = _resolveNewFileSelection(
      subtitleData: subtitleData,
      srtFileInfo: srtFileInfo,
    );

    final collection = SubtitleCollection(
      fileName: fileSelection.fileName,
      encoding: subtitleData.encoding,
      filePath: fileSelection.filePath,
      originalFileUri: fileSelection.fileUri,
      lines: subtitleLines,
    );

    late Session session;
    await _isar.writeTxn(() async {
      final collectionId = await _isar.subtitleCollections.put(collection);
      session = Session(
        subtitleCollectionId: collectionId,
        fileName: fileSelection.fileName,
        lastEditedIndex: sessionData.lastEditedIndex,
        editMode: sessionData.editMode ?? true,
        projectFilePath: originalProjectUri,
      );
      await _isar.sessions.put(session);
      await _persistCheckpointsInTransaction(
        sessionId: session.id,
        subtitleCollectionId: collectionId,
        history: history,
        referencePlan: referencePlan,
      );
    });

    return session;
  }

  List<SubtitleLine> _parseSubtitleLines(
    List<ProjectSubtitleLineData> source,
  ) {
    return source.map(_toSubtitleLine).toList(growable: false);
  }

  SubtitleLine _toSubtitleLine(ProjectSubtitleLineData data) {
    return SubtitleLine()
      ..index = data.index
      ..startTime = data.startTime
      ..endTime = data.endTime
      ..original = data.original
      ..edited = data.edited
      ..marked = data.marked
      ..comment = data.comment
      ..resolved = data.resolved;
  }

  void _applySubtitleFileSelection({
    required SubtitleCollection collection,
    required ProjectSubtitleCollectionData subtitleData,
    required Map<String, String?> srtFileInfo,
  }) {
    if (srtFileInfo['useExistingProject'] == 'true') {
      return;
    }

    if (srtFileInfo['useImportingFile'] == 'true') {
      collection.fileName = subtitleData.fileName ?? collection.fileName;
      collection.originalFileUri =
          subtitleData.originalFileUri ?? subtitleData.filePath;
      collection.filePath = subtitleData.filePath;
      return;
    }

    collection.fileName =
        srtFileInfo['fileName'] ??
        subtitleData.fileName ??
        collection.fileName;

    if (Platform.isAndroid && srtFileInfo['safUri'] != null) {
      collection.originalFileUri = srtFileInfo['safUri'];
    } else {
      collection.originalFileUri =
          srtFileInfo['fileUri'] ?? srtFileInfo['filePath'];
    }
    collection.filePath = srtFileInfo['filePath'];
  }

  void _applySessionSelection({
    required Session session,
    required ProjectSubtitleCollectionData subtitleData,
    required ProjectSessionData sessionData,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
  }) {
    if (srtFileInfo['useImportingFile'] == 'true') {
      session.fileName = subtitleData.fileName ?? session.fileName;
    } else if (srtFileInfo['useExistingProject'] != 'true') {
      session.fileName =
          srtFileInfo['fileName'] ??
          subtitleData.fileName ??
          session.fileName;
    }

    if (sessionData.lastEditedIndex != null) {
      session.lastEditedIndex = sessionData.lastEditedIndex;
    }
    if (sessionData.editMode != null) {
      session.editMode = sessionData.editMode!;
    }
    session.projectFilePath = originalProjectUri;
  }

  _ResolvedFileSelection _resolveNewFileSelection({
    required ProjectSubtitleCollectionData subtitleData,
    required Map<String, String?> srtFileInfo,
  }) {
    if (srtFileInfo['useImportingFile'] == 'true') {
      return _ResolvedFileSelection(
        fileName: subtitleData.fileName ?? 'Imported Project',
        filePath: subtitleData.filePath,
        fileUri: subtitleData.originalFileUri ?? subtitleData.filePath,
      );
    }

    final fileName =
        srtFileInfo['fileName'] ??
        subtitleData.fileName ??
        'Imported Project';
    final filePath = srtFileInfo['filePath'];

    final fileUri = Platform.isAndroid && srtFileInfo['safUri'] != null
        ? srtFileInfo['safUri']
        : srtFileInfo['fileUri'] ?? filePath;

    return _ResolvedFileSelection(
      fileName: fileName,
      filePath: filePath,
      fileUri: fileUri,
    );
  }

  /// Called only inside the surrounding session/collection write transaction.
  /// The source graph has already been validated in memory.
  Future<void> _persistCheckpointsInTransaction({
    required int sessionId,
    required int subtitleCollectionId,
    required PreparedProjectHistory? history,
    required CheckpointReferenceMigrationPlan? referencePlan,
  }) async {
    if (history == null || history.checkpoints.isEmpty) return;

    final imported = <Checkpoint>[];
    final idMap = <int, int>{};
    for (final source in history.checkpoints) {
      final checkpoint = Checkpoint(
        sessionId: sessionId,
        subtitleCollectionId: subtitleCollectionId,
        timestamp: source.timestamp,
        operationType: source.operationType,
        description: source.description,
        parentCheckpointId: null,
        isActive: false,
        checkpointType: source.checkpointType,
        metadata: source.metadata,
        deltas: source.deltas,
        snapshot: source.snapshot,
      );
      final newId = await _isar.checkpoints.put(checkpoint);
      imported.add(checkpoint);
      idMap[source.id] = newId;
    }

    for (var i = 0; i < history.checkpoints.length; i++) {
      final original = history.checkpoints[i];
      final parentId = original.parentCheckpointId;
      if (parentId != null) {
        final mappedParent = idMap[parentId];
        if (mappedParent == null) {
          throw StateError('Validated project graph lost parent $parentId.');
        }
        imported[i].parentCheckpointId = mappedParent;
      }
      imported[i].isActive = original.isActive;
    }
    // Explicitly preserve the selected HEAD after ID remapping.
    final head = history.checkpoints
        .where((checkpoint) => checkpoint.isActive)
        .firstOrNull;
    if (head != null) {
      CheckpointHeadReference.moveInMemory(
        checkpoints: imported,
        checkpointId: idMap[head.id]!,
      );
    }
    // Remap all portable reference targets before the transaction completes.
    // Durable ref persistence is deliberately deferred until generated Isar
    // schemas are verified. Only derived refs were accepted by preflight.
    referencePlan?.remap(
      destinationSessionId: sessionId,
      destinationCollectionId: subtitleCollectionId,
      idMap: idMap,
    );
    await _isar.checkpoints.putAll(imported);
  }

}

class _ResolvedFileSelection {
  final String fileName;
  final String? filePath;
  final String? fileUri;

  const _ResolvedFileSelection({
    required this.fileName,
    required this.filePath,
    required this.fileUri,
  });
}
