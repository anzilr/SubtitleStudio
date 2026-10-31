import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/core/file_access/project_document_update_service.dart';

/// Platform file-I/O boundary for .msone project documents.
///
/// This service performs file writes only. It does not show dialogs/snackbars,
/// navigate, or mutate project/session database state.
class ProjectFileService {
  const ProjectFileService._();

  static Future<String?> saveAndroidProject({
    required String content,
    required String fileName,
  }) async {
    final fileInfo = await PlatformFileHandler.saveNewFile(
      content: content,
      fileName: fileName,
      mimeType: 'application/octet-stream',
    );

    if (fileInfo == null) return null;
    return fileInfo.safUri ?? fileInfo.path;
  }

  static Future<String?> saveIosProject({
    required String content,
    required String fileName,
  }) async {
    final contentBytes = Uint8List.fromList(utf8.encode(content));

    final saved = await fp.FilePicker.saveFile(
      dialogTitle: 'Save Project File',
      fileName: fileName,
      bytes: contentBytes,
    );
    if (saved == null) return null;
    return saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
  }

  static Future<String> saveDesktopProject({
    required String content,
    required String directoryPath,
    required String fileName,
  }) async {
    final filePath =
        '$directoryPath${Platform.pathSeparator}$fileName';
    await File(filePath).writeAsString(content);
    return filePath;
  }

  static Future<bool> updateExistingProject({
    required String content,
    required String projectFilePath,
    ProjectDocumentUpdateService updater =
        const ProjectDocumentUpdateService(),
  }) =>
      updater.update(
        content: content,
        projectFilePath: projectFilePath,
      );
}
