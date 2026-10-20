import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// Injectable byte access that distinguishes Android document grants from
/// native filesystem paths. Domain and UI code should not open file locators.
abstract class SecondarySubtitleByteSource {
  bool get isAndroid;
  Future<Uint8List> readNative(String path);
  Future<Uint8List> readDocument(String uri);
}

final class DeviceSecondarySubtitleByteSource
    implements SecondarySubtitleByteSource {
  const DeviceSecondarySubtitleByteSource();

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  Future<Uint8List> readNative(String path) => File(path).readAsBytes();

  @override
  Future<Uint8List> readDocument(String uri) =>
      SafFileHandler.readFileFromUri(uri);
}

/// Source identity and parsing for optional secondary subtitle documents.
///
/// Does not access Isar or modify persisted paths, and never routes a content
/// URI to File(...). Retains strict UTF-8 policy until the CP89 codec audit.
final class SecondarySubtitleDocumentReader {
  const SecondarySubtitleDocumentReader({
    SecondarySubtitleByteSource byteSource =
        const DeviceSecondarySubtitleByteSource(),
  }) : _bytes = byteSource;

  final SecondarySubtitleByteSource _bytes;

  Future<List<SimpleSubtitleLine>> readAndParse(String locator) async {
    final identity = StudioFileIdentity.fromLocator(locator);
    final data = await _read(identity);
    final text = utf8.decode(data, allowMalformed: false);
    final extension = _detectExtension(identity, text);
    switch (extension) {
      case 'srt':
        return SubtitleParser.parseSrt(text);
      case 'vtt':
        return SubtitleParser.parseVtt(text);
      case 'ass':
      case 'ssa':
        return SubtitleParser.parseAss(text);
      default:
        throw const FormatException('Unsupported secondary subtitle format.');
    }
  }

  Future<Uint8List> _read(StudioFileIdentity identity) {
    switch (identity.kind) {
      case StudioFileLocationKind.nativePath:
        return _bytes.readNative(identity.location);
      case StudioFileLocationKind.androidDocument:
        if (!_bytes.isAndroid) {
          throw const FileSystemException(
              'Android document reader is not available on this platform.');
        }
        return _bytes.readDocument(identity.location);
      case StudioFileLocationKind.fileUri:
        final uri = Uri.parse(identity.location);
        return _bytes.readNative(
            uri.toFilePath(windows: Platform.isWindows));
      case StudioFileLocationKind.remoteUri:
      case StudioFileLocationKind.opaqueUri:
        throw const FileSystemException(
            'Secondary subtitle source is not a local document.');
    }
  }

  static String _detectExtension(
      StudioFileIdentity identity, String content) {
    final path = identity.kind == StudioFileLocationKind.nativePath
        ? identity.location
        : Uri.parse(identity.location).pathSegments.last;
    final fileName = path.replaceAll(String.fromCharCode(92), '/').split('/').last.toLowerCase();
    for (final ext in const ['srt', 'vtt', 'ass', 'ssa']) {
      if (fileName.endsWith('.$ext')) return ext;
    }
    // Some SAF providers expose only opaque document IDs. Recognize a
    // signature for those documents; never infer a type for unknown files.
    if (identity.isAndroidDocument) {
      final text = content.trimLeft();
      if (text.startsWith('WEBVTT')) return 'vtt';
      if (text.startsWith('[Script Info]') ||
          text.startsWith('[Events]')) return 'ass';
      if (RegExp(r'(?:^|\n)\s*(?:\d+\s*\n)?\s*\d{2}:\d{2}:\d{2},\d{3}\s*-->')
          .hasMatch(text.replaceAll('\r\n', '\n'))) return 'srt';
    }
    throw const FormatException('Unsupported secondary subtitle format.');
  }
}
