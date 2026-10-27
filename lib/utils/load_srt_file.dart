import 'package:flutter/material.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/intent_handler.dart';
import 'dart:io';

Future<Map?> pickSRT(BuildContext context) async {
  // Use the new platform-specific file picker with both display path and SAF URI
  final fileInfo = await FilePickerConvenience.pickSubtitleFileWithInfo(context: context);
  
  if (fileInfo != null) {
    final displayPath = fileInfo['displayPath']!;
    final safUri = fileInfo['safUri'];
    final accessLocator = fileInfo['accessLocator'];
    final content = fileInfo['content'];
    final bytes = fileInfo['bytes']; // Keep raw bytes for lossless decoding
    
    // Extract filename from the best available source
    String fileName;
    if (safUri != null && safUri.isNotEmpty) {
      // For SAF URIs, use the IntentHandler to get proper filename
      fileName = IntentHandler.getFileName(safUri);
    } else {
      // For regular paths, extract filename from path
      fileName = displayPath.split(Platform.pathSeparator).last;
    }
    
    // Keep the real filename. Relabeling an unsupported format as .srt would
    // bypass the import guard and could later overwrite its source on Save.
    
    return {
      'filePath': displayPath,
      'fileName': fileName,
      'safUri': safUri, // Existing originalFileUri metadata
      'accessLocator': accessLocator, // Actual file source, not displayPath
      'content': content,
      'bytes': bytes,
    };
  }
  return null;
}



