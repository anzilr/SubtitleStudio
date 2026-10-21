import 'dart:io';
import 'dart:typed_data';

import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';

/// Output is prepared before any picker, permission request, or file write.
/// The UI decides whether to export edited or original cues; both paths use
/// the same strict text encoder and retain deliberately blank edited lines.
final class EditorExportPlan {
  const EditorExportPlan({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  EditorExportPlan renamed(String fileName) =>
      EditorExportPlan(fileName: fileName, bytes: bytes);
}

enum EditorExportWriteResult { saved, alreadyExists }

abstract class EditorExportFileOperations {
  Future<bool> directoryExists(String path);
  Future<bool> fileExists(String path);
  Future<void> writeBytes(String path, Uint8List bytes);
}

final class DeviceEditorExportFileOperations
    implements EditorExportFileOperations {
  const DeviceEditorExportFileOperations();

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}

/// UI-free export preparation and desktop write boundary. File-provider
/// dialogs remain in the calling widget, where a BuildContext is available.
final class EditorExportService {
  EditorExportService({
    EditorExportFileOperations? files,
    SubtitleExtendedEncodingService codec =
        SubtitleExtendedEncodingService.standard,
    bool? isWindows,
  })  : _files = files ?? const DeviceEditorExportFileOperations(),
        _codec = codec,
        _isWindows = isWindows ?? Platform.isWindows;

  final EditorExportFileOperations _files;
  final SubtitleExtendedEncodingService _codec;
  final bool _isWindows;

  /// A file name is a single component, never a second path supplied by the
  /// filename or custom tag fields. Reject Windows-reserved punctuation on
  /// all hosts so the same project can be exported across desktop systems.
  static void _validateComponent(String value) {
    if (value.isEmpty || value == '.' || value == '..' ||
        value.endsWith('.') ||
        RegExp(r'[\\/:*?"<>|\x00-\x1f]').hasMatch(value)) {
      throw ArgumentError.value(value, 'fileName', 'Invalid export file name');
    }
  }

  String fileNameFor({
    required String requestedName,
    required String customTag,
    required bool originalOnly,
  }) {
    final base = requestedName.trim().replaceFirst(
      RegExp(r'\.srt$', caseSensitive: false), '',
    );
    _validateComponent(base);
    if (originalOnly) return '$base.original.srt';

    // Preserve the existing convention without duplicating a final .msone.
    if (base.toLowerCase().endsWith('.msone')) return '$base.srt';
    final tag = customTag.trim().isEmpty ? 'MSone' : customTag.trim();
    _validateComponent(tag);
    return '$base.$tag.srt';
  }

  Future<EditorExportPlan> prepare({
    required List<SubtitleLine> lines,
    required String encoding,
    required String requestedName,
    required String customTag,
    required bool originalOnly,
  }) async {
    final fileName = fileNameFor(
      requestedName: requestedName,
      customTag: customTag,
      originalOnly: originalOnly,
    );
    final bytes = await SrtCompiler.generateSrtBytesExtended(
      lines,
      encoding: encoding,
      forceOriginal: originalOnly,
      service: _codec,
    );
    return EditorExportPlan(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  String _nativeDirectory(String folder) {
    final identity = StudioFileIdentity.fromLocator(folder.trim());
    final String directory;
    switch (identity.kind) {
      case StudioFileLocationKind.nativePath:
        directory = _isWindows
            ? identity.location.replaceAll('/', r'\')
            : identity.location;
        break;
      case StudioFileLocationKind.fileUri:
        final uri = Uri.parse(identity.location);
        if (!_isWindows && uri.host.isNotEmpty) {
          throw ArgumentError.value(folder, 'folder', 'Not a local folder');
        }
        directory = uri.toFilePath(windows: _isWindows);
        break;
      default:
        throw ArgumentError.value(folder, 'folder', 'Not a local folder');
    }
    if (directory.trim().isEmpty) {
      throw ArgumentError.value(folder, 'folder', 'Select a folder');
    }
    return directory;
  }

  String destinationPath(String folder, EditorExportPlan plan) {
    _validateComponent(plan.fileName);
    final directory = _nativeDirectory(folder);
    final separator = _isWindows ? r'\' : '/';
    return '${directory.endsWith(separator) ? directory : '$directory$separator'}${plan.fileName}';
  }

  /// A remembered source filename is not itself an output directory.
  /// Authoritative SAF/remote identities never yield a synthetic local folder
  /// from the collection's separate display-path hint.
  String? suggestedFolder({String? originalFileUri, String? legacyFilePath}) {
    final original = originalFileUri?.trim();
    final locator = original != null && original.isNotEmpty
        ? original
        : legacyFilePath?.trim();
    if (locator == null || locator.isEmpty) return null;
    try {
      final nativeFile = _nativeDirectory(locator);
      final separator = _isWindows ? r'\' : '/';
      final separatorIndex = nativeFile.lastIndexOf(separator);
      if (separatorIndex < 0) return null;
      if (separatorIndex == 0) return separator;
      // Retain C:\ rather than turning a Windows drive root into C:.
      if (_isWindows && separatorIndex == 2 && nativeFile[1] == ':') {
        return nativeFile.substring(0, 3);
      }
      return nativeFile.substring(0, separatorIndex);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  Future<bool> existsInFolder(String folder, EditorExportPlan plan) =>
      _files.fileExists(destinationPath(folder, plan));

  Future<EditorExportWriteResult> writeDesktop({
    required String folder,
    required EditorExportPlan plan,
    bool replaceExisting = false,
  }) async {
    final path = destinationPath(folder, plan);
    if (!await _files.directoryExists(_nativeDirectory(folder))) {
      throw const FileSystemException('Selected export folder does not exist');
    }
    // A rename to another existing file is NOT implicit permission to
    // overwrite that file. Only the explicit Replace choice sets this flag.
    if (!replaceExisting && await _files.fileExists(path)) {
      return EditorExportWriteResult.alreadyExists;
    }
    await _files.writeBytes(path, plan.bytes);
    return EditorExportWriteResult.saved;
  }
}
