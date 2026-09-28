import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/database/models/models.dart';

/// Persistence boundary for project/session metadata.
///
/// Project document serialization and platform file I/O intentionally live
/// elsewhere. This repository owns only database-backed project metadata.
class ProjectRepository {
  final Isar _isar;

  const ProjectRepository(this._isar);

  Future<Session?> getSession(int sessionId) {
    return _isar.sessions.get(sessionId);
  }

  Future<String?> getProjectFilePath(int sessionId) async {
    return (await getSession(sessionId))?.projectFilePath;
  }

  Future<void> updateSessionProjectPath({
    required int sessionId,
    required String? projectFilePath,
  }) async {
    await _isar.writeTxn(() async {
      final session = await _isar.sessions.get(sessionId);
      if (session == null) {
        throw StateError('Session not found: $sessionId');
      }

      session.projectFilePath = projectFilePath;
      await _isar.sessions.put(session);
    });
  }
}
