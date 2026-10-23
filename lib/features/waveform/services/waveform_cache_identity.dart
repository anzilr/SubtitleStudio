import 'dart:convert';
import 'dart:io';

import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';

/// Cache key scoped to source path, selected audio stream, and local file
/// version (size + mtime). For content URIs, stat/version is unavailable;
/// versioned SAF metadata is supplied explicitly where available.
class WaveformCacheIdentity {
  const WaveformCacheIdentity._();

  static Future<String> pcmPath({
    required String temporaryDirectory,
    required int subtitleCollectionId,
    required String sourcePath,
    String? audioTrackId,
    String? sourceRevision,
  }) async {
    final track = audioTrackId == null ||
            audioTrackId.isEmpty || audioTrackId == 'auto'
        ? 'auto' : audioTrackId;
    var sourceVersion = '';
    if (StudioFileIdentity.fromLocator(sourcePath).canStatLocally) {
      try {
        final stat = await File(sourcePath).stat();
        if (stat.type == FileSystemEntityType.file) {
          sourceVersion = '|' + stat.size.toString() + '|' +
              stat.modified.microsecondsSinceEpoch.toString();
        }
      } on FileSystemException {
        // Virtual/missing source: still key by the path and track.
      }
    }
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(
        sourcePath + '|' + track + sourceVersion +
        (sourceRevision == null ? '' : '|revision:' + sourceRevision))) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    final name = 'waveform_audio_' + subtitleCollectionId.toString() +
        '_' + hash.toRadixString(16).padLeft(8, '0') + '.raw';
    return temporaryDirectory.endsWith(Platform.pathSeparator)
        ? temporaryDirectory + name
        : temporaryDirectory + Platform.pathSeparator + name;
  }

  /// The processor writes 16-bit little-endian, 44.1-kHz mono PCM.
  static bool metadataValid({
    required String actualPath,
    required String expectedPath,
    required int byteLength,
    required int totalSamples,
    required int channels,
    required int sampleRate,
  }) =>
      actualPath == expectedPath &&
      channels == 1 &&
      sampleRate == 44100 &&
      totalSamples > 0 &&
      byteLength == totalSamples * 2;
}
