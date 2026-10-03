import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

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
  }) async {
    final subtitleData = projectDocument.subtitleCollection;
    final subtitleLines = _parseSubtitleLines(subtitleData.lines);

    final collection =
        await _isar.subtitleCollections.get(session.subtitleCollectionId);
    if (collection == null) {
      throw StateError('Session subtitle collection not found');
    }

    _applySubtitleFileSelection(
      collection: collection,
      subtitleData: subtitleData,
      srtFileInfo: srtFileInfo,
    );
    collection.encoding = subtitleData.encoding;
    collection.lines = subtitleLines;

    _applySessionSelection(
      session: session,
      subtitleData: subtitleData,
      sessionData: projectDocument.session,
      srtFileInfo: srtFileInfo,
      originalProjectUri: originalProjectUri,
    );

    await _isar.writeTxn(() async {
      await _isar.subtitleCollections.put(collection);
      await _isar.sessions.put(session);
    });

    await _importCheckpoints(
      sessionId: session.id,
      subtitleCollectionId: session.subtitleCollectionId,
      checkpoints: projectDocument.checkpoints,
    );

    return session;
  }

  Future<Session> importAsNewSession({
    required ProjectDocument projectDocument,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
  }) async {
    final sessionData = projectDocument.session;
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
    });

    await _importCheckpoints(
      sessionId: session.id,
      subtitleCollectionId: session.subtitleCollectionId,
      checkpoints: projectDocument.checkpoints,
    );

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

  Future<void> _importCheckpoints({
    required int sessionId,
    required int subtitleCollectionId,
    required List<ProjectCheckpointData> checkpoints,
  }) async {
    if (checkpoints.isEmpty) return;

    try {
      final sourceIds = <int>{};
      final parentById = <int, int?>{};

      for (final data in checkpoints) {
        final sourceId = data.id;
        if (sourceId == null) {
          throw const FormatException(
            'Project checkpoint history has no stable checkpoint IDs. '
            'Subtitle data can still be imported, but history cannot be '
            'safely reconstructed.',
          );
        }
        if (!sourceIds.add(sourceId)) {
          throw FormatException(
            'Project checkpoint history contains duplicate ID $sourceId.',
          );
        }
        parentById[sourceId] = data.parentCheckpointId;
      }

      for (final entry in parentById.entries) {
        final parentId = entry.value;
        if (parentId != null && !sourceIds.contains(parentId)) {
          throw FormatException(
            'Project checkpoint ${entry.key} references missing parent '
            '$parentId.',
          );
        }
      }

      for (final sourceId in sourceIds) {
        final visited = <int>{};
        int? currentId = sourceId;
        while (currentId != null) {
          if (!visited.add(currentId)) {
            throw FormatException(
              'Project checkpoint history contains a parent cycle at '
              '$currentId.',
            );
          }
          currentId = parentById[currentId];
        }
      }

      final imported = <Checkpoint>[];
      final idMap = <int, int>{};
      int? importedHeadIndex;

      for (var i = 0; i < checkpoints.length; i++) {
        if (!checkpoints[i].isActive) continue;
        if (importedHeadIndex == null) {
          importedHeadIndex = i;
          continue;
        }

        final currentTimestamp =
            DateTime.tryParse(checkpoints[i].timestamp ?? '');
        final selectedTimestamp =
            DateTime.tryParse(checkpoints[importedHeadIndex].timestamp ?? '');
        if (currentTimestamp != null &&
            (selectedTimestamp == null ||
                currentTimestamp.isAfter(selectedTimestamp))) {
          importedHeadIndex = i;
        }
      }

      if (importedHeadIndex == null) {
        for (var i = 0; i < checkpoints.length; i++) {
          final currentTimestamp =
              DateTime.tryParse(checkpoints[i].timestamp ?? '');
          if (currentTimestamp == null) continue;
          if (importedHeadIndex == null) {
            importedHeadIndex = i;
            continue;
          }
          final selectedTimestamp =
              DateTime.tryParse(checkpoints[importedHeadIndex].timestamp ?? '');
          if (selectedTimestamp == null ||
              currentTimestamp.isAfter(selectedTimestamp)) {
            importedHeadIndex = i;
          }
        }
      }

      await _isar.writeTxn(() async {
        for (var i = 0; i < checkpoints.length; i++) {
          final data = checkpoints[i];
          final timestamp = data.timestamp;
          if (timestamp == null) {
            throw const FormatException(
              'Project checkpoint is missing its timestamp.',
            );
          }

          final checkpoint = Checkpoint(
            sessionId: sessionId,
            subtitleCollectionId: subtitleCollectionId,
            timestamp: DateTime.parse(timestamp),
            operationType: data.operationType,
            description: data.description,
            parentCheckpointId: null,
            isActive: false,
            checkpointType: data.checkpointType,
            metadata: data.metadata,
            deltas: data.deltas.map(_toDelta).toList(growable: false),
            snapshot: _parseSubtitleLines(data.snapshot),
          );

          final newId = await _isar.checkpoints.put(checkpoint);
          imported.add(checkpoint);
          idMap[data.id!] = newId;
        }

        for (var i = 0; i < checkpoints.length; i++) {
          final parentKey = checkpoints[i].parentCheckpointId;
          if (parentKey != null) {
            final mappedParent = idMap[parentKey];
            if (mappedParent == null) {
              throw FormatException(
                'Project checkpoint parent $parentKey could not be remapped.',
              );
            }
            imported[i].parentCheckpointId = mappedParent;
          }

          imported[i].isActive = i == importedHeadIndex;
          await _isar.checkpoints.put(imported[i]);
        }
      });
    } catch (error, stackTrace) {
      logWarning(
        'Project checkpoint import failed: $error',
        stackTrace: stackTrace,
      );
    }
  }

  SubtitleLineDelta _toDelta(ProjectDeltaData data) {
    return SubtitleLineDelta()
      ..changeType = data.changeType
      ..lineIndex = data.lineIndex
      ..beforeState =
          data.beforeState == null ? null : _toSubtitleLine(data.beforeState!)
      ..afterState =
          data.afterState == null ? null : _toSubtitleLine(data.afterState!);
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
