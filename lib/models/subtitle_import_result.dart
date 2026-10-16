import 'package:subtitle_studio/database/models/models.dart';

/// Typed result returned after subtitle import persistence succeeds.
class SubtitleImportResult {
  final int subtitleCollectionId;
  final String fileName;
  final int? lastEditedIndex;
  final int sessionId;
  final bool editMode;
  final Session session;
  final SubtitleCollection subtitleCollection;

  const SubtitleImportResult({
    required this.subtitleCollectionId,
    required this.fileName,
    required this.lastEditedIndex,
    required this.sessionId,
    required this.editMode,
    required this.session,
    required this.subtitleCollection,
  });

  factory SubtitleImportResult.fromLegacyMap(Map<String, dynamic> data) {
    final collectionId = data['subtitleCollectionId'];
    final sessionId = data['sessionId'];
    final session = data['session'];
    final collection = data['subtitleCollection'];

    if (collectionId is! int ||
        sessionId is! int ||
        session is! Session ||
        collection is! SubtitleCollection) {
      throw StateError('Subtitle import persistence returned invalid data.');
    }

    return SubtitleImportResult(
      subtitleCollectionId: collectionId,
      fileName: data['fileName'] is String ? data['fileName'] as String : '',
      lastEditedIndex:
          data['lastEditedIndex'] is int ? data['lastEditedIndex'] as int : null,
      sessionId: sessionId,
      editMode: data['editMode'] is bool ? data['editMode'] as bool : false,
      session: session,
      subtitleCollection: collection,
    );
  }

  Map<String, dynamic> toLegacyMap() {
    return {
      'subtitleCollectionId': subtitleCollectionId,
      'fileName': fileName,
      'lastEditedIndex': lastEditedIndex,
      'sessionId': sessionId,
      'editMode': editMode,
      'session': session,
      'subtitleCollection': subtitleCollection,
    };
  }
}
