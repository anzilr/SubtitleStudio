import 'dart:io';

/// FFmpegKit requires a granted SAF input handle rather than a raw Android
/// content URI. Do not silently feed an inaccessible URI into FFmpeg.
class WaveformSafInput {
  const WaveformSafInput._();

  static const documentAccessMessage =
      'Unable to open the selected Android document for waveform decoding. '
      'Please select the file again to restore access.';

  static Future<String> resolve(
    String sourcePath, {
    required bool android,
    required Future<String?> Function(String) safParameterForRead,
  }) async {
    if (!android || !sourcePath.startsWith('content://')) return sourcePath;
    try {
      final parameter = await safParameterForRead(sourcePath);
      if (parameter != null && parameter.trim().isNotEmpty) {
        return parameter;
      }
    } catch (_) {
      // Mask provider internals/document identifiers in user-visible errors.
    }
    throw const FileSystemException(documentAccessMessage);
  }
}
