import 'dart:io';

import 'subtitle_text_codec.dart';
import 'subtitle_extended_encoding_service.dart';
export 'subtitle_text_codec.dart' show DecodedSubtitleContent;

/// All file imports share the portable, byte-level decoder.
class SubtitleEncodingDecoder {
  const SubtitleEncodingDecoder._();

  static DecodedSubtitleContent decodeBytes(List<int> bytes,
      {String? selectedEncoding}) =>
      SubtitleTextCodec.decode(bytes, selectedEncoding: selectedEncoding);

  static Future<DecodedSubtitleContent> decodeFile(File file,
      {String? selectedEncoding}) async =>
      SubtitleExtendedEncodingService.standard.decode(
        await file.readAsBytes(), selectedEncoding: selectedEncoding);

  static Future<DecodedSubtitleContent> decodeBytesExtended(
    List<int> bytes, {String? selectedEncoding}) =>
      SubtitleExtendedEncodingService.standard.decode(
        bytes, selectedEncoding: selectedEncoding);
}
