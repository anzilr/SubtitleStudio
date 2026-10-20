import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';

/// Source View reads/writes through one injectable boundary rather than
/// allowing its Riverpod controller to operate on platform locators directly.
final sourceViewFileAccessProvider = Provider<SourceViewFileAccess>(
  (ref) => SourceViewFileAccessImpl(),
);

enum SourceViewSaveDestination { androidDocument, nativeFile }

final class SourceViewCreatedDocument {
  const SourceViewCreatedDocument({
    required this.uri,
    required this.displayPath,
  });

  final String uri;
  final String displayPath;
}

/// Platform-agnostic file operations for Source View. No UI, Isar or
/// subtitle encoding decisions live here.
abstract class SourceViewFileAccess {
  Future<Uint8List> read(SourceViewFileTarget source);
  Future<SourceViewSaveDestination?> write(
    SourceViewFileTarget source, Uint8List bytes);
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  });
  Future<bool> writeCreatedDocument(
    SourceViewCreatedDocument document, Uint8List bytes);
}

/// Adapter to existing app platform channels and dart:io. Reuse the shipped
/// SAF entry points (and their grant semantics), do not add native plugins.
abstract class SourceViewFileOperations {
  bool get isAndroid;
  Future<Uint8List?> readNative(String path);
  Future<bool> writeNative(String path, Uint8List bytes);
  Future<Uint8List?> readDocument(String uri);
  Future<bool> writeDocument(String uri, Uint8List bytes);
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  });
}

final class SourceViewDeviceFileOperations implements SourceViewFileOperations {
  const SourceViewDeviceFileOperations();

  static const _intentChannel =
      MethodChannel('org.malayalamsubtitles.studio/intent');

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Future<Uint8List?> readNative(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> writeNative(String path, Uint8List bytes) async {
    final file = File(path);
    // Preserve R1's existing-file-only policy: no accidental new file when
    // the intended destination is unavailable.
    if (!await file.exists()) return false;
    await file.writeAsBytes(bytes);
    return true;
  }

  @override
  Future<Uint8List?> readDocument(String uri) =>
      _intentChannel.invokeMethod<Uint8List>(
        'readFileFromContentUri', {'uri': uri},
      );

  @override
  Future<bool> writeDocument(String uri, Uint8List bytes) =>
      SafFileHandler.writeSafUri(uri, bytes);

  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) async {
    final selected = await SafFileHandler.createDocument(
      fileName: fileName,
      mimeType: mimeType,
    );
    if (selected == null) return null;
    return SourceViewCreatedDocument(
      uri: selected.uri,
      displayPath: selected.displayPath,
    );
  }
}

/// Source identity and fallback policy is validated before performing IO.
/// Revocation is handled per attempt; a direct content URI never falls
/// back to an unrelated local path or silently redirects output.
final class SourceViewFileAccessImpl implements SourceViewFileAccess {
  SourceViewFileAccessImpl({SourceViewFileOperations? operations})
      : _operations = operations ?? const SourceViewDeviceFileOperations();

  final SourceViewFileOperations _operations;

  @override
  Future<Uint8List> read(SourceViewFileTarget source) async {
    final document = source.androidDocumentUri;
    if (_operations.isAndroid && document != null) {
      try {
        final bytes = await _operations.readDocument(document);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      } catch (_) {
        // An existing native cached source can be used when the SAF
        // provider refuses access; direct content URI has no such fallback.
      }
    }

    if (source.canFallbackToLocalFile) {
      final native = await _operations.readNative(source.source.location);
      if (native != null) return native;
    }
    throw const FileSystemException(
      'Source View document cannot be read with the current permissions.',
    );
  }

  @override
  Future<SourceViewSaveDestination?> write(
    SourceViewFileTarget source, Uint8List bytes,
  ) async {
    final document = source.androidDocumentUri;
    if (_operations.isAndroid && document != null) {
      try {
        if (await _operations.writeDocument(document, bytes)) {
          return SourceViewSaveDestination.androidDocument;
        }
      } catch (_) {
        // Same local fallback policy as read, never a different document.
      }
    }

    if (source.canFallbackToLocalFile) {
      try {
        if (await _operations.writeNative(source.source.location, bytes)) {
          return SourceViewSaveDestination.nativeFile;
        }
      } on FileSystemException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<SourceViewCreatedDocument?> createDocument({
    required String fileName,
    required String mimeType,
  }) {
    if (!_operations.isAndroid) {
      throw UnsupportedError('SAF Save As requires Android.');
    }
    return _operations.createDocument(
      fileName: fileName, mimeType: mimeType,
    );
  }

  @override
  Future<bool> writeCreatedDocument(
    SourceViewCreatedDocument document, Uint8List bytes,
  ) {
    if (!_operations.isAndroid) {
      throw UnsupportedError('SAF Save As requires Android.');
    }
    final identity = StudioFileIdentity.fromLocator(document.uri);
    if (!identity.isAndroidDocument) {
      throw const FormatException('Invalid Save As document URI.');
    }
    return _operations.writeDocument(document.uri, bytes);
  }
}
