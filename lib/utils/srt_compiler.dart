import 'dart:io';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import '../database/models/models.dart';
import 'platform_check.dart';

class SrtCompiler {
  /// Compiles subtitle lines into an SRT file
  ///
  /// Takes a [SubtitleCollection] object and compiles it into an SRT file
  /// If [forceOriginal] is true, will use the original text even if edited text exists
  static Future<void> compileSrt(SubtitleCollection subtitle, {bool forceOriginal = false}) async {
    try {
      // Validate every character against the selected charset (including
      // its BOM setting) before requesting file access, making directories,
      // or touching an existing destination. A failed conversion is not a
      // reason to modify a user's on-disk subtitle.
      final bytes = await generateSrtBytesExtended(
        subtitle.lines,
        encoding: subtitle.encoding,
        forceOriginal: forceOriginal,
      );

      // Request storage permissions before attempting to write
      if (Platform.isAndroid) {
        final hasPermission = await requestStoragePermissions();
        if (!hasPermission) {
          throw Exception('Storage permission is required to save files. Please grant permission in app settings.');
        }
      } else if (Platform.isIOS) {
        // On iOS, we cannot write to arbitrary file paths due to sandbox restrictions
        // The file picker returns a path, but we don't have write access to it
        throw Exception('iOS: Cannot write to arbitrary file path due to sandbox restrictions. Please use the file picker to save.');
      }
      
      final file = File(subtitle.filePath!);
      
      // Create directory if it doesn't exist
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      
      // Test write permissions by creating a temporary file
      try {
        final testFile = File('${file.parent.path}/test_write_${DateTime.now().millisecondsSinceEpoch}.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        throw Exception('Cannot write to selected directory. Please select a different location or check app permissions.');
      }
      
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw Exception('Error compiling SRT: $e');
    }
  }
  
  /// Generate SRT content as a string without writing to file
  static String generateSrtContent(List<SubtitleLine> lines, {bool forceOriginal = false}) {
    final buffer = StringBuffer();
    
    for (final line in lines) {
      // Null means no edit; an explicitly empty edited value is a deliberate
      // blank subtitle and must not silently export the original line.
      var text = forceOriginal
          ? line.original
          : line.edited ?? line.original;
      
      // Replace <br> tags with actual line breaks
      text = text.replaceAll('<br>', '\n');
      
      // Write subtitle entry
      buffer.writeln(line.index);
      buffer.writeln('${line.startTime} --> ${line.endTime}');
      buffer.writeln(text);
      buffer.writeln(); // Empty line between entries
    }
    
    return buffer.toString();
  }
  
  /// Encoding-neutral SRT compilation for SAF and iOS byte export.
  static List<int> generateSrtBytes(List<SubtitleLine> lines, {
    required String encoding,
    bool forceOriginal = false,
  }) => SubtitleTextCodec.encode(
      generateSrtContent(lines, forceOriginal: forceOriginal),
      encoding: encoding,
    );

  /// Regional encodings use the same validated async codec on every platform.
  static Future<List<int>> generateSrtBytesExtended(
    List<SubtitleLine> lines, {
    required String encoding,
    bool forceOriginal = false,
    SubtitleExtendedEncodingService service =
        SubtitleExtendedEncodingService.standard,
  }) => service.encode(
      generateSrtContent(lines, forceOriginal: forceOriginal),
      encoding: encoding,
    );
}
