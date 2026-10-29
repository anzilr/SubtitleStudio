import 'dart:io';

import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/subtitle_encoding_decoder.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/utils/subtitle_processor.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

enum StudioDockProjectSrtSource {
  archive,
  existingSession,
  locatedFile,
  unlinked,
}

/// The user's explicit choices after inspecting a portable project archive.
/// A missing source file is never silently linked to a writable SRT.
class StudioDockProjectImportPlan {
  const StudioDockProjectImportPlan({
    required this.source,
    this.replaceSessionId,
    this.locatedSrtPath,
  });

  final StudioDockProjectSrtSource source;
  final int? replaceSessionId;
  final String? locatedSrtPath;
}

class StudioDockProjectImportTarget {
  const StudioDockProjectImportTarget({
    required this.session,
    this.srtPath,
  });

  final Session session;
  final String? srtPath;
}

/// Shared, non-navigating persistence boundary for the Studio Dock desktop
/// project actions. Reuses the production encoding, parser and Isar services.
class StudioDockProjectActions {
  const StudioDockProjectActions({
    required this.subtitleImporter,
    required this.projectImporter,
  });

  final SubtitleImportRepository subtitleImporter;
  final SessionProjectImportRepository projectImporter;

  // Full VTT/ASS/SSA document round-trip support is still on the roadmap.
  // Do not link a format-flattened import to a source that Save could replace.
  static const supportedExtensions = <String>{'.srt', '.msone'};

  static String extensionOf(String path) {
    final name = Uri.file(path).pathSegments.last.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot);
  }

  static String displayName(String path) =>
      Uri.file(path).pathSegments.last;

  Future<Session> importFile(String path, {
    String? selectedEncoding,
    bool removeHearingImpaired = false,
    bool mergeOverlapping = false,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('The selected file does not exist.');
    }
    final extension = extensionOf(path);
    if (!supportedExtensions.contains(extension)) {
      throw const FormatException('Unsupported subtitle or project file.');
    }
    if (extension == '.msone') {
      throw const FormatException(
        'Review the project import options before importing a .msone file.',
      );
    }
    final decoded = await SubtitleEncodingDecoder.decodeFile(file,
        selectedEncoding: selectedEncoding);
    if (removeHearingImpaired || mergeOverlapping) {
      // Reuse mobile's import transformations, including timing fixes and
      // reindexing. Only the explicit opt-in path changes cue content.
      final result = await processSubtitleContentWithoutContext(
        decoded.content, displayName(path), path,
        removeHearingImpairedLines: removeHearingImpaired,
        mergeOverlappingSubtitles: mergeOverlapping,
        contentUri: path,
        encoding: decoded.encoding,
        repository: subtitleImporter,
      );
      return result.session;
    }
    final parsed = SubtitleParser.parseSrt(decoded.content);
    if (parsed.isEmpty) {
      throw const FormatException('No valid subtitle lines were found.');
    }
    final lines = [
      for (final cue in parsed)
        SubtitleLine()
          ..index = cue.index
          ..startTime = cue.startTime.replaceAll('.', ',')
          ..endTime = cue.endTime.replaceAll('.', ',')
          ..original = cue.text
          ..edited = null
          ..marked = false
          ..comment = null
          ..resolved = false,
    ];
    final result = await subtitleImporter.storeSubtitleData(
      lines: lines,
      fileName: displayName(path),
      encoding: decoded.encoding,
      filePath: path,
      originalFileUri: path,
    );
    await subtitleImporter.updateLastEditedSession(result.sessionId);
    return result.session;
  }

  Future<ProjectDocument> readProjectDocument(String path) async {
    if (extensionOf(path) != '.msone') {
      throw const FormatException('Choose a .msone project file.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('The selected project does not exist.');
    }
    return ProjectDocumentCodec.decode(await file.readAsString());
  }

  Future<List<StudioDockProjectImportTarget>> importTargets() async {
    final sessions = await projectImporter.fetchSessions();
    final targets = <StudioDockProjectImportTarget>[];
    for (final session in sessions) {
      final collection = await projectImporter.getSubtitleCollection(
        session.subtitleCollectionId,
      );
      targets.add(StudioDockProjectImportTarget(
        session: session,
        srtPath: collection?.filePath ?? collection?.originalFileUri,
      ));
    }
    return targets;
  }

  static String? archivedSrtPath(ProjectDocument document) =>
      document.subtitleCollection.filePath ?? document.originalFileUri;

  /// A desktop reference must be an existing local SRT. The archive's path
  /// may point to another computer; merely having a path is not sufficient.
  static Future<bool> isUsableSrtPath(String? path) async {
    if (path == null || path.trim().isEmpty || extensionOf(path) != '.srt') {
      return false;
    }
    return File(path).exists();
  }

  Future<Session> importProject({
    required String archivePath,
    required ProjectDocument document,
    required StudioDockProjectImportPlan plan,
    bool importSubtitlesOnly = false,
  }) async {
    if (!await File(archivePath).exists() ||
        extensionOf(archivePath) != '.msone') {
      throw const FileSystemException('The project archive is unavailable.');
    }

    final targetId = plan.replaceSessionId;
    Session? target;
    if (targetId != null) {
      final sessions = await projectImporter.fetchSessions();
      for (final session in sessions) {
        if (session.id == targetId) {
          target = session;
          break;
        }
      }
      if (target == null) {
        throw StateError('The project selected for replacement no longer exists.');
      }
    }

    late final Map<String, String?> fileInfo;
    switch (plan.source) {
      case StudioDockProjectSrtSource.archive:
        final source = archivedSrtPath(document);
        if (!await isUsableSrtPath(source)) {
          throw const FileSystemException(
              'The SRT referenced by this archive is not available.');
        }
        fileInfo = {
          'fileName': displayName(source!),
          'filePath': source,
          'fileUri': source,
        };
        break;
      case StudioDockProjectSrtSource.existingSession:
        if (target == null) {
          throw const FormatException(
              'An existing subtitle file requires a replacement project.');
        }
        final collection = await projectImporter.getSubtitleCollection(
          target.subtitleCollectionId,
        );
        final source = collection?.filePath ?? collection?.originalFileUri;
        if (!await isUsableSrtPath(source)) {
          throw const FileSystemException(
              'The selected project no longer has an accessible SRT file.');
        }
        fileInfo = const {'useExistingProject': 'true'};
        break;
      case StudioDockProjectSrtSource.locatedFile:
        final source = plan.locatedSrtPath;
        if (!await isUsableSrtPath(source)) {
          throw const FileSystemException('Choose an existing .srt file.');
        }
        fileInfo = {
          'fileName': displayName(source!),
          'filePath': source,
          'fileUri': source,
        };
        break;
      case StudioDockProjectSrtSource.unlinked:
        fileInfo = {
          'fileName': document.subtitleCollection.fileName ??
              document.session.fileName ?? 'Imported subtitles.srt',
          'filePath': null,
          'fileUri': null,
        };
        break;
    }

    final session = target == null
        ? await projectImporter.importAsNewSession(
            projectDocument: document,
            srtFileInfo: fileInfo,
            originalProjectUri: archivePath,
            importSubtitlesOnly: importSubtitlesOnly,
          )
        : await projectImporter.replaceSession(
            session: target,
            projectDocument: document,
            srtFileInfo: fileInfo,
            originalProjectUri: archivePath,
            importSubtitlesOnly: importSubtitlesOnly,
          );
    await subtitleImporter.updateLastEditedSession(session.id);
    return session;
  }

  static String fileNameForNewProject(String title) {
    final normalized = title.trim();
    if (normalized.isEmpty || normalized == '.' || normalized == '..') {
      throw const FormatException('Enter a project name.');
    }
    if (RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(normalized)) {
      throw const FormatException('Project names cannot contain file-path characters.');
    }
    if (RegExp(r'\.(vtt|ass|ssa)$', caseSensitive: false)
        .hasMatch(normalized)) {
      throw const FormatException('New projects currently support SRT only.');
    }
    return normalized.toLowerCase().endsWith('.srt')
        ? normalized : '$normalized.srt';
  }

  Future<Session> createEmpty(String title, {String encoding = 'UTF-8'}) async {
    final fileName = fileNameForNewProject(title);
    if (!const ['UTF-8', 'ISO-8859-1', 'Windows-1252']
        .contains(encoding)) {
      throw const FormatException('Choose a supported SRT encoding.');
    }
    // An empty project has no export location until the user explicitly
    // chooses one. Never silently create or overwrite an external .srt.
    final result = await subtitleImporter.storeSubtitleData(
      lines: <SubtitleLine>[],
      fileName: fileName,
      encoding: encoding,
      filePath: '',
      editMode: true,
    );
    await subtitleImporter.updateLastEditedSession(result.sessionId);
    return result.session;
  }
}
