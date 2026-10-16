import 'package:flutter/services.dart';
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';

/// An Android DocumentsProvider can expose a stable size + modified timestamp.
/// Without both values, no persistent waveform cache may be trusted for SAF.
abstract final class WaveformSourceRevision {
  static const MethodChannel _channel =
      MethodChannel('org.malayalamsubtitles.studio/saf');

  static String? fromMetadata(Map<Object?, Object?>? metadata) {
    if (metadata == null) return null;
    final size = metadata['size'];
    final modified = metadata['modified'];
    if (size is! int || modified is! int || size <= 0 || modified <= 0) {
      return null;
    }
    return 'size=$size;modified=$modified';
  }

  static Future<String?> forSafUri(String uri) async {
    if (!StudioFileIdentity.fromLocator(uri).isAndroidDocument) return null;
    try {
      final metadata = await _channel.invokeMapMethod<Object?, Object?>(
        'getDocumentRevision', <String, String>{'uri': uri},
      );
      return fromMetadata(metadata);
    } on PlatformException {
      // Older Android builds and metadata-limited providers stay nonpersistent.
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
