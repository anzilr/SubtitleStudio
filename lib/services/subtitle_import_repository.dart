import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/models/subtitle_import_result.dart';
import 'package:subtitle_studio/utils/logging_helpers.dart';

/// Persistence boundary for subtitle import/create workflows.
///
/// Parsing, encoding detection, cleanup transforms, and file selection belong
/// outside this repository. This class owns only Isar-backed import state.
class SubtitleImportRepository {
  final Isar _isar;

  const SubtitleImportRepository(this._isar);

  Future<SubtitleImportResult> storeSubtitleData({
    required List<SubtitleLine> lines,
    required String fileName,
    required String encoding,
    required String filePath,
    bool editMode = false,
    String? originalFileUri,
    String? projectFilePath,
    String? macOsSrtBookmark,
  }) async {
    await logInfo(
      'Storing subtitle import: $fileName with ${lines.length} lines',
      context: 'SubtitleImportRepository.storeSubtitleData',
    );

    final collection = SubtitleCollection(
      fileName: fileName,
      encoding: encoding,
      filePath: filePath,
      originalFileUri: originalFileUri,
      lines: lines,
      macOsSrtBookmark: macOsSrtBookmark,
    );

    late final int collectionId;
    await _isar.writeTxn(() async {
      collectionId = await _isar.subtitleCollections.put(collection);
    });
    collection.id = collectionId;

    final session = Session(
      subtitleCollectionId: collectionId,
      fileName: fileName,
      lastEditedIndex: null,
      editMode: editMode,
      projectFilePath: projectFilePath,
    );

    late final int sessionId;
    await _isar.writeTxn(() async {
      sessionId = await _isar.sessions.put(session);
    });
    session.id = sessionId;

    return SubtitleImportResult(
      subtitleCollectionId: collectionId,
      fileName: fileName,
      lastEditedIndex: null,
      sessionId: sessionId,
      editMode: editMode,
      session: session,
      subtitleCollection: collection,
    );
  }

  Future<void> updateLastEditedSession(int sessionId) async {
    if (sessionId <= 0) {
      if (kDebugMode) {
        debugPrint('Ignoring invalid last-edited session ID: $sessionId');
      }
      return;
    }

    await _isar.writeTxn(() async {
      final preferences =
          await _isar.preferences.where().findFirst() ??
          Preferences(autoSave: true);
      preferences.lastEditedSession = sessionId;
      await _isar.preferences.put(preferences);
    });
  }
}
