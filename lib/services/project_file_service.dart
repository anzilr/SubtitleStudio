import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:subtitle_studio/utils/platform_file_handler.dart';

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
  }) {
    final contentBytes = Uint8List.fromList(utf8.encode(content));

    return fp.FilePicker.platform.saveFile(
      dialogTitle: 'Save Project File',
      fileName: fileName,
      type: fp.FileType.custom,
      allowedExtensions: const ['msone'],
      bytes: contentBytes,
    );
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
  }) async {
    if (Platform.isAndroid && projectFilePath.startsWith('content://')) {
      return PlatformFileHandler.writeFile(
        content: content,
        filePath: projectFilePath,
      );
    }

    if (Platform.isIOS) {
      // iOS document-provider paths are not assumed to remain writable after
      // the picker closes. The caller will fall back to Save As.
      return false;
    }

    await File(projectFilePath).writeAsString(content);
    return true;
  }
}
