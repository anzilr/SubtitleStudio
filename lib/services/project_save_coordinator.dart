import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/project_document_builder.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/project_file_service.dart';

/// UI-free coordinator for creating and persisting .msone project documents.
///
/// Dialogs, Snackbars, folder selection, navigation, and BuildContext ownership
/// intentionally remain outside this class.
class ProjectSaveCoordinator {
  static const String projectVersion = '2.0';
  static const String appVersion = '3.0.0';

  final CheckpointRepository _checkpointRepository;

  const ProjectSaveCoordinator(this._checkpointRepository);

  String suggestedProjectFileName(
    Session session, {
    String? suggestedFileName,
  }) {
    return (suggestedFileName ?? session.fileName)
            .replaceAll(RegExp(r'\.[^.]*$'), '') +
        '.msone';
  }

  Future<ProjectDocument> buildDocument({
    required Session session,
    required SubtitleCollection subtitleCollection,
  }) async {
    final checkpoints =
        await _checkpointRepository.getCheckpointsForSession(session.id);

    return ProjectDocumentBuilder.build(
      session: session,
      subtitleCollection: subtitleCollection,
      checkpoints: checkpoints,
      projectVersion: projectVersion,
      appVersion: appVersion,
    );
  }

  Future<String?> saveAndroidNew({
    required Session session,
    required SubtitleCollection subtitleCollection,
    String? suggestedFileName,
  }) async {
    final document = await buildDocument(
      session: session,
      subtitleCollection: subtitleCollection,
    );

    return ProjectFileService.saveAndroidProject(
      content: ProjectDocumentCodec.encode(document),
      fileName: suggestedProjectFileName(
        session,
        suggestedFileName: suggestedFileName,
      ),
    );
  }

  Future<String?> saveIosNew({
    required Session session,
    required SubtitleCollection subtitleCollection,
    String? suggestedFileName,
  }) async {
    final document = await buildDocument(
      session: session,
      subtitleCollection: subtitleCollection,
    );

    return ProjectFileService.saveIosProject(
      content: ProjectDocumentCodec.encode(document),
      fileName: suggestedProjectFileName(
        session,
        suggestedFileName: suggestedFileName,
      ),
    );
  }

  Future<String> saveDesktopNew({
    required Session session,
    required SubtitleCollection subtitleCollection,
    required String directoryPath,
    String? suggestedFileName,
  }) async {
    final document = await buildDocument(
      session: session,
      subtitleCollection: subtitleCollection,
    );

    return ProjectFileService.saveDesktopProject(
      content: ProjectDocumentCodec.encode(document),
      directoryPath: directoryPath,
      fileName: suggestedProjectFileName(
        session,
        suggestedFileName: suggestedFileName,
      ),
    );
  }

  Future<bool> updateExisting({
    required Session session,
    required SubtitleCollection subtitleCollection,
  }) async {
    final projectFilePath = session.projectFilePath;
    if (projectFilePath == null || projectFilePath.isEmpty) {
      return false;
    }

    final document = await buildDocument(
      session: session,
      subtitleCollection: subtitleCollection,
    );

    return ProjectFileService.updateExistingProject(
      content: ProjectDocumentCodec.encode(document),
      projectFilePath: projectFilePath,
    );
  }
}
