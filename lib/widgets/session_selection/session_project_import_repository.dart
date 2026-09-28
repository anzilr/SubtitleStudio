import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';
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
    required Map<String, dynamic> projectData,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
  }) async {
    final sessionData =
        Map<String, dynamic>.from(projectData['session'] as Map);
    final subtitleData =
        Map<String, dynamic>.from(projectData['subtitleCollection'] as Map);
    final subtitleLines = _parseSubtitleLines(subtitleData['lines']);

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
    collection.encoding =
        subtitleData['encoding'] as String? ?? collection.encoding;
    collection.lines = subtitleLines;

    _applySessionSelection(
      session: session,
      subtitleData: subtitleData,
      sessionData: sessionData,
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
      projectData: projectData,
    );

    return session;
  }

  Future<Session> importAsNewSession({
    required Map<String, dynamic> projectData,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
  }) async {
    final sessionData =
        Map<String, dynamic>.from(projectData['session'] as Map);
    final subtitleData =
        Map<String, dynamic>.from(projectData['subtitleCollection'] as Map);
    final subtitleLines = _parseSubtitleLines(subtitleData['lines']);

    final fileSelection = _resolveNewFileSelection(
      subtitleData: subtitleData,
      srtFileInfo: srtFileInfo,
    );

    final collection = SubtitleCollection(
      fileName: fileSelection.fileName,
      encoding: subtitleData['encoding'] as String? ?? 'UTF-8',
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
        lastEditedIndex: sessionData['lastEditedIndex'] as int?,
        editMode: sessionData['editMode'] as bool? ?? true,
        projectFilePath: originalProjectUri,
      );
      await _isar.sessions.put(session);
    });

    await _importCheckpoints(
      sessionId: session.id,
      subtitleCollectionId: session.subtitleCollectionId,
      projectData: projectData,
    );

    return session;
  }

  List<SubtitleLine> _parseSubtitleLines(dynamic rawLines) {
    final source = rawLines is List ? rawLines : const <dynamic>[];
    return source.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      return SubtitleLine()
        ..index = data['index'] as int? ?? 0
        ..startTime = data['startTime'] as String? ?? ''
        ..endTime = data['endTime'] as String? ?? ''
        ..original = data['original'] as String? ?? ''
        ..edited = data['edited'] as String?
        ..marked = data['marked'] as bool? ?? false
        ..comment = data['comment'] as String?
        ..resolved = data['resolved'] as bool? ?? false;
    }).toList(growable: false);
  }

  void _applySubtitleFileSelection({
    required SubtitleCollection collection,
    required Map<String, dynamic> subtitleData,
    required Map<String, String?> srtFileInfo,
  }) {
    if (srtFileInfo['useExistingProject'] == 'true') {
      return;
    }

    if (srtFileInfo['useImportingFile'] == 'true') {
      collection.fileName =
          subtitleData['fileName'] as String? ?? collection.fileName;
      collection.originalFileUri =
          subtitleData['originalFileUri'] as String? ??
          subtitleData['filePath'] as String?;
      collection.filePath = subtitleData['filePath'] as String?;
      return;
    }

    collection.fileName =
        srtFileInfo['fileName'] ??
        subtitleData['fileName'] as String? ??
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
    required Map<String, dynamic> subtitleData,
    required Map<String, dynamic> sessionData,
    required Map<String, String?> srtFileInfo,
    required String? originalProjectUri,
  }) {
    if (srtFileInfo['useImportingFile'] == 'true') {
      session.fileName =
          subtitleData['fileName'] as String? ?? session.fileName;
    } else if (srtFileInfo['useExistingProject'] != 'true') {
      session.fileName =
          srtFileInfo['fileName'] ??
          subtitleData['fileName'] as String? ??
          session.fileName;
    }

    if (sessionData['lastEditedIndex'] is int) {
      session.lastEditedIndex = sessionData['lastEditedIndex'] as int;
    }
    if (sessionData['editMode'] is bool) {
      session.editMode = sessionData['editMode'] as bool;
    }
    session.projectFilePath = originalProjectUri;
  }

  _ResolvedFileSelection _resolveNewFileSelection({
    required Map<String, dynamic> subtitleData,
    required Map<String, String?> srtFileInfo,
  }) {
    if (srtFileInfo['useImportingFile'] == 'true') {
      return _ResolvedFileSelection(
        fileName:
            subtitleData['fileName'] as String? ?? 'Imported Project',
        filePath: subtitleData['filePath'] as String?,
        fileUri:
            subtitleData['originalFileUri'] as String? ??
            subtitleData['filePath'] as String?,
      );
    }

    final fileName =
        srtFileInfo['fileName'] ??
        subtitleData['fileName'] as String? ??
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
    required Map<String, dynamic> projectData,
  }) async {
    final raw = projectData['checkpoints'];
    if (raw is! List || raw.isEmpty) return;

    try {
      final imported = <Checkpoint>[];
      final idMap = <Object, int>{};

      await _isar.writeTxn(() async {
        for (int i = 0; i < raw.length; i++) {
          final data = Map<String, dynamic>.from(raw[i] as Map);
          final checkpoint = Checkpoint(
            sessionId: sessionId,
            subtitleCollectionId: subtitleCollectionId,
            timestamp: DateTime.parse(data['timestamp'] as String),
            operationType: data['operationType'] as String? ?? 'unknown',
            description: data['description'] as String? ?? '',
            parentCheckpointId: null,
            isActive: data['isActive'] as bool? ?? false,
            checkpointType: data['checkpointType'] as String? ?? 'delta',
            metadata: data['metadata'] as String?,
            deltas: _parseDeltas(data['deltas']),
            snapshot: _parseSubtitleLines(data['snapshot']),
          );

          final newId = await _isar.checkpoints.put(checkpoint);
          imported.add(checkpoint);
          idMap[data['id'] ?? i] = newId;
        }

        for (int i = 0; i < raw.length && i < imported.length; i++) {
          final data = Map<String, dynamic>.from(raw[i] as Map);
          final parentKey = data['parentCheckpointId'];
          if (parentKey == null) continue;

          int? mappedParent = idMap[parentKey];
          mappedParent ??= i > 0 ? imported[i - 1].id : null;

          if (mappedParent != null) {
            imported[i].parentCheckpointId = mappedParent;
            await _isar.checkpoints.put(imported[i]);
          }
        }
      });
    } catch (error, stackTrace) {
      logWarning(
        'Project checkpoint import failed: $error',
        stackTrace: stackTrace,
      );
    }
  }

  List<SubtitleLineDelta> _parseDeltas(dynamic rawDeltas) {
    final source = rawDeltas is List ? rawDeltas : const <dynamic>[];
    return source.map((raw) {
      final data = Map<String, dynamic>.from(raw as Map);
      final delta = SubtitleLineDelta()
        ..changeType = data['changeType'] as String? ?? ''
        ..lineIndex = data['lineIndex'] as int? ?? 0;

      if (data['beforeState'] is Map) {
        delta.beforeState =
            _parseSubtitleLines([data['beforeState']]).single;
      }
      if (data['afterState'] is Map) {
        delta.afterState =
            _parseSubtitleLines([data['afterState']]).single;
      }

      return delta;
    }).toList(growable: false);
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
