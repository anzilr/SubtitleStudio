import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_access.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';

/// The actual destination selected by Save As. The display path is kept for
/// legacy project compatibility; the original URI is the write authority.
final class EditLineSavedLocation {
  const EditLineSavedLocation({
    required this.filePath,
    required this.originalFileUri,
  });

  final String filePath;
  final String originalFileUri;
}

/// UI-free Save As boundary so the Edit Line screen owns only confirmation and
/// feedback, not Android SAF, iOS file-provider or desktop byte writing.
abstract class EditLineSaveAsPicker {
  Future<EditLineSavedLocation?> save({
    required String fileName,
    required Uint8List bytes,
  });
}

final class DeviceEditLineSaveAsPicker implements EditLineSaveAsPicker {
  const DeviceEditLineSaveAsPicker();

  @override
  Future<EditLineSavedLocation?> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (Platform.isAndroid) {
      final saved = await PlatformFileHandler.saveNewFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/x-subrip',
      );
      final uri = saved?.safUri;
      if (uri == null || uri.isEmpty) return null;
      return EditLineSavedLocation(
        filePath: saved!.path,
        originalFileUri: uri,
      );
    }

    // iOS' document picker receives bytes and performs the file-provider
    // export. Its returned location must never be written again with File().
    final path = Platform.isIOS
        ? await fp.FilePicker.platform.saveFile(
            dialogTitle: 'Save Subtitle File',
            fileName: fileName,
            type: fp.FileType.custom,
            allowedExtensions: const ['srt'],
            bytes: bytes,
          )
        : await fp.FilePicker.platform.saveFile(
            dialogTitle: 'Save Subtitle File',
            fileName: fileName,
            type: fp.FileType.custom,
            allowedExtensions: const ['srt'],
          );
    if (path == null || path.isEmpty) return null;
    if (!Platform.isIOS) {
      final identity = StudioFileIdentity.fromLocator(path);
      if (!identity.canStatLocally) {
        throw const FileSystemException('Save As returned a non-local path.');
      }
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return EditLineSavedLocation(filePath: path, originalFileUri: path);
  }
}

/// File-save orchestration shared by mobile and the future desktop workspace.
///
/// Bytes are validated before any file chooser or write. An original content
/// URI is authoritative: a failed/revoked SAF write must not redirect data to
/// a synthetic display path that happens to be stored in `filePath`.
final class EditLineFileSaveService {
  EditLineFileSaveService({
    SourceViewFileAccess? access,
    EditLineSaveAsPicker? picker,
    SubtitleExtendedEncodingService codec =
        SubtitleExtendedEncodingService.standard,
  })  : _access = access ?? SourceViewFileAccessImpl(),
        _picker = picker ?? const DeviceEditLineSaveAsPicker(),
        _codec = codec;

  final SourceViewFileAccess _access;
  final EditLineSaveAsPicker _picker;
  final SubtitleExtendedEncodingService _codec;

  Future<Uint8List> prepareBytes(
    SubtitleCollection collection,
    List<SubtitleLine> lines,
  ) async => Uint8List.fromList(await SrtCompiler.generateSrtBytesExtended(
        lines,
        encoding: collection.encoding,
        service: _codec,
      ));

  Future<bool> saveExisting(
    SubtitleCollection collection,
    Uint8List bytes,
  ) async {
    final original = collection.originalFileUri;
    final location = original != null && original.trim().isNotEmpty
        ? original
        : collection.filePath;
    if (location == null || location.trim().isEmpty) return false;

    try {
      final identity = StudioFileIdentity.fromLocator(location);
      if (identity.kind != StudioFileLocationKind.androidDocument &&
          identity.kind != StudioFileLocationKind.nativePath &&
          identity.kind != StudioFileLocationKind.fileUri) {
        return false;
      }
      return await _access.write(
            SourceViewFileTarget.resolve(filePath: location),
            bytes,
          ) !=
          null;
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  Future<EditLineSavedLocation?> saveAs(
    SubtitleCollection collection,
    Uint8List bytes,
  ) async {
    final name = collection.fileName;
    final fileName = name.toLowerCase().endsWith('.srt')
        ? name
        : '$name.srt';
    return _picker.save(fileName: fileName, bytes: bytes);
  }
}
