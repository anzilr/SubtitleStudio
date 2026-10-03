import 'dart:convert';
import 'dart:io';

import 'package:charset_converter/charset_converter.dart';

class DecodedSubtitleContent {
  final String content;
  final String encoding;

  const DecodedSubtitleContent({
    required this.content,
    required this.encoding,
  });
}

/// Reads subtitle text while preserving which decoder actually succeeded.
class SubtitleEncodingDecoder {
  const SubtitleEncodingDecoder._();

  static Future<DecodedSubtitleContent> decodeFile(File file) async {
    try {
      final fileStat = await file.stat();
      final fileSizeInMb = fileStat.size / (1024 * 1024);

      if (fileSizeInMb > 5) {
        final stream = file.openRead();
        final buffer = StringBuffer();
        await for (final chunk in stream.transform(utf8.decoder)) {
          buffer.write(chunk);
        }
        return DecodedSubtitleContent(
          content: buffer.toString(),
          encoding: 'UTF-8',
        );
      }

      return DecodedSubtitleContent(
        content: await file.readAsString(encoding: utf8),
        encoding: 'UTF-8',
      );
    } catch (_) {
      final bytes = await file.readAsBytes();

      try {
        return DecodedSubtitleContent(
          content: await CharsetConverter.decode('latin1', bytes),
          encoding: 'ISO-8859-1',
        );
      } catch (_) {
        try {
          return DecodedSubtitleContent(
            content: await CharsetConverter.decode('windows-1252', bytes),
            encoding: 'Windows-1252',
          );
        } catch (_) {
          try {
            return DecodedSubtitleContent(
              content: await CharsetConverter.decode('utf16', bytes),
              encoding: 'UTF-16',
            );
          } catch (_) {
            return DecodedSubtitleContent(
              content: String.fromCharCodes(bytes),
              encoding: 'Unknown',
            );
          }
        }
      }
    }
  }
}
