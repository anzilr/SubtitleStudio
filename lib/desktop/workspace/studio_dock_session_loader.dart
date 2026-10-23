import 'package:subtitle_studio/app/repositories/project_repository.dart';
import 'package:subtitle_studio/screens/edit/repositories/subtitle_repository.dart';

import 'studio_dock_session_snapshot.dart';

/// Safe DS3 read-only route into the existing repositories.
///
/// No new Isar schema, no checkpoint creation, no write transaction. The
/// session-to-collection ownership check prevents accidental cross-session
/// mixing when a desktop window opens or switches projects.
class StudioDockSessionLoader {
  const StudioDockSessionLoader(this._projects, this._subtitles);

  final ProjectRepository _projects;
  final SubtitleRepository _subtitles;

  Future<StudioDockSessionSnapshot> load({
    required int sessionId,
    required int collectionId,
  }) async {
    final session = await _projects.getSession(sessionId);
    if (session == null) {
      throw StateError('The requested subtitle session no longer exists.');
    }
    if (session.subtitleCollectionId != collectionId) {
      throw StateError('The subtitle collection does not belong to this session.');
    }
    final collection = await _subtitles.fetchSubtitleCollection(collectionId);
    if (collection == null) {
      throw StateError('The subtitle collection could not be found.');
    }
    return StudioDockSessionSnapshot(
      sessionId: sessionId,
      collectionId: collectionId,
      fileName: collection.fileName,
      encoding: collection.encoding,
      cues: [
        for (final line in collection.lines)
          StudioDockLoadedCue(
            index: line.index,
            start: line.startTime,
            end: line.endTime,
            original: line.original,
            edited: line.edited ?? '',
            marked: line.marked,
          ),
      ],
    );
  }
}
