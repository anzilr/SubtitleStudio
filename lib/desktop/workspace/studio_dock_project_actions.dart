import 'dart:io';

import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/subtitle_encoding_decoder.dart';
import 'package:subtitle_studio/services/subtitle_import_repository.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';

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

  Future<Session> importFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('The selected file does not exist.');
    }
    final extension = extensionOf(path);
    if (!supportedExtensions.contains(extension)) {
      throw const FormatException('Unsupported subtitle or project file.');
    }
    if (extension == '.msone') return _importProject(path);
    final decoded = await SubtitleEncodingDecoder.decodeFile(file);
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

  Future<Session> _importProject(String path) async {
    final data = ProjectDocumentCodec.decode(await File(path).readAsString());
    // Keep the complete history graph, including bookmarks and checkpoint
    // references. Link the archive's existing subtitle identity where
    // available; the source file may need relinking at future Save As.
    final session = await projectImporter.importAsNewSession(
      projectDocument: data,
      srtFileInfo: const {'useImportingFile': 'true'},
      originalProjectUri: path,
    );
    await subtitleImporter.updateLastEditedSession(session.id);
    return session;
  }

  Future<Session> createEmpty(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Enter a project name.');
    }
    final fileName = normalized.toLowerCase().endsWith('.srt')
        ? normalized : '$normalized.srt';
    // An empty project has no export location until the user explicitly
    // chooses one. Never silently create or overwrite an external .srt.
    final result = await subtitleImporter.storeSubtitleData(
      lines: <SubtitleLine>[],
      fileName: fileName,
      encoding: 'UTF-8',
      filePath: '',
      editMode: true,
    );
    await subtitleImporter.updateLastEditedSession(result.sessionId);
    return result.session;
  }
}
