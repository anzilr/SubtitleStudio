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
}
