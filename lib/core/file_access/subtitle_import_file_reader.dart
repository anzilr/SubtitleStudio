import 'dart:io';
import 'dart:typed_data';

import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';

/// A source locator for raw subtitle import. Unlike displayPath it is safe to
/// use as an IO target after platform-grant checks.
final class SubtitleImportFileReference {
  const SubtitleImportFileReference._(this.source, this.safUri);

  final StudioFileIdentity source;
  final String? safUri;

  String get accessLocator => source.persistedLocator;

  static SubtitleImportFileReference resolve({
    required String filePath,
    String? safUri,
    String? accessLocator,
  }) {
    final selected = accessLocator?.trim();
    final grant = safUri?.trim();
    final identity = StudioFileIdentity.fromLocator(
      selected != null && selected.isNotEmpty ? accessLocator! : filePath,
    );
    if (grant != null && grant.isNotEmpty) {
      final granted = StudioFileIdentity.fromLocator(safUri!);
      if (!granted.isAndroidDocument) {
        throw const FormatException('Invalid subtitle SAF source URI.');
      }
      if (identity.isAndroidDocument &&
          identity.persistedLocator != safUri) {
        throw const FormatException('Subtitle source and SAF grant differ.');
      }
    }
    // If the display path is a synthetic /storage/... path and the grant is a
    // content document, always prefer the document. Cached local files remain
    // independent sources and cannot be conflated with this display hint.
    if (identity.kind == StudioFileLocationKind.remoteUri ||
        identity.kind == StudioFileLocationKind.opaqueUri) {
      throw const FormatException('Unsupported subtitle import location.');
    }
    return SubtitleImportFileReference._(
      grant != null && grant.isNotEmpty
          ? StudioFileIdentity.fromLocator(safUri!)
          : identity,
      grant != null && grant.isNotEmpty
          ? safUri
          : identity.isAndroidDocument ? identity.location : null,
    );
  }
}

/// Narrow platform adapter: Android documents cannot fall through to File().
abstract class SubtitleImportByteAccess {
  bool get isAndroid;
  bool get isWindows;
  Future<Uint8List> readNative(String path);
  Future<Uint8List> readDocument(String uri);
}

final class DeviceSubtitleImportByteAccess implements SubtitleImportByteAccess {
  const DeviceSubtitleImportByteAccess();

  @override
  bool get isAndroid => Platform.isAndroid;
  @override
  bool get isWindows => Platform.isWindows;
  @override
  Future<Uint8List> readNative(String path) => File(path).readAsBytes();
  @override
  Future<Uint8List> readDocument(String uri) =>
      SafFileHandler.readFileFromUri(uri);
}

/// Keeps selected raw bytes identical for encoding preview and final import.
final class SubtitleImportFileReader {
  const SubtitleImportFileReader({
    SubtitleImportByteAccess access = const DeviceSubtitleImportByteAccess(),
  }) : _access = access;

  final SubtitleImportByteAccess _access;

  Future<Uint8List> read(SubtitleImportFileReference selection) {
    switch (selection.source.kind) {
      case StudioFileLocationKind.androidDocument:
        if (!_access.isAndroid) {
          throw const FileSystemException('Android document access unavailable.');
        }
        return _access.readDocument(selection.accessLocator);
      case StudioFileLocationKind.nativePath:
        return _access.readNative(selection.accessLocator);
      case StudioFileLocationKind.fileUri:
        return _access.readNative(
          Uri.parse(selection.accessLocator).toFilePath(
            windows: _access.isWindows,
          ),
        );
      case StudioFileLocationKind.remoteUri:
      case StudioFileLocationKind.opaqueUri:
        throw const FileSystemException('Unsupported subtitle import source.');
    }
  }
}
