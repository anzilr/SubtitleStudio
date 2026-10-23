import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';

/// Existing-project updates must not interpret arbitrary URI strings as paths.
///
/// Native project and SAF writes use separate adapters so this service can be
/// exercised without a file picker, Android or Isar.
abstract class ProjectDocumentUpdateStorage {
  bool get isAndroid;
  bool get isIos;
  bool get isWindows;
  Future<bool> writeExistingNativeFile(String path, String content);
  Future<bool> writeAndroidDocument(String uri, String content);
}

final class DeviceProjectDocumentUpdateStorage
    implements ProjectDocumentUpdateStorage {
  const DeviceProjectDocumentUpdateStorage();

  @override
  bool get isAndroid => Platform.isAndroid;
  @override
  bool get isIos => Platform.isIOS;
  @override
  bool get isWindows => Platform.isWindows;

  @override
  Future<bool> writeExistingNativeFile(String path, String content) async {
    final file = File(path);
    // Updating a missing original must not silently create a new .msone
    // document. Let the caller offer Save As instead.
    try {
      if (!await file.exists()) return false;
      await file.writeAsString(content);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<bool> writeAndroidDocument(String uri, String content) async {
    try {
      return await SafFileHandler.writeSafUri(
          uri, Uint8List.fromList(utf8.encode(content)));
    } on Exception {
      // A revoked SAF grant, missing plugin or provider failure must offer
      // Save As rather than exposing document identifiers in UI errors.
      return false;
    }
  }
}

/// Routing policy for .msone updates, isolated from file selection and Isar.
///
/// A persisted locator is retained verbatim; only a file URI may be converted
/// to a native path for the purpose of the I/O operation.
final class ProjectDocumentUpdateService {
  const ProjectDocumentUpdateService({
    ProjectDocumentUpdateStorage storage =
        const DeviceProjectDocumentUpdateStorage(),
  }) : _storage = storage;

  final ProjectDocumentUpdateStorage _storage;

  Future<bool> update({
    required String projectFilePath,
    required String content,
  }) async {
    final StudioFileIdentity identity;
    try {
      identity = StudioFileIdentity.fromLocator(projectFilePath);
    } on FormatException {
      return false;
    }

    if (_storage.isIos) {
      // iOS document-provider locations are not assumed writable once the
      // picker closes; the caller must offer Save As.
      return false;
    }

    switch (identity.kind) {
      case StudioFileLocationKind.androidDocument:
        if (!_storage.isAndroid) return false;
        return _storage.writeAndroidDocument(identity.location, content);
      case StudioFileLocationKind.nativePath:
        return _storage.writeExistingNativeFile(identity.location, content);
      case StudioFileLocationKind.fileUri:
        try {
          final path = Uri.parse(identity.location)
              .toFilePath(windows: _storage.isWindows);
          return await _storage.writeExistingNativeFile(path, content);
        } on FormatException {
          return false;
        } on UnsupportedError {
          return false;
        } on ArgumentError {
          return false;
        }
      case StudioFileLocationKind.remoteUri:
      case StudioFileLocationKind.opaqueUri:
        return false;
    }
  }
}
