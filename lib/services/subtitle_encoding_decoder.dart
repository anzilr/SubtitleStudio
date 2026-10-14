import 'dart:io';

import 'subtitle_text_codec.dart';
export 'subtitle_text_codec.dart' show DecodedSubtitleContent;

/// All file imports share the portable, byte-level decoder.
class SubtitleEncodingDecoder {
  const SubtitleEncodingDecoder._();

  static DecodedSubtitleContent decodeBytes(List<int> bytes,
      {String? selectedEncoding}) =>
      SubtitleTextCodec.decode(bytes, selectedEncoding: selectedEncoding);

  static Future<DecodedSubtitleContent> decodeFile(File file,
      {String? selectedEncoding}) async =>
      decodeBytes(await file.readAsBytes(), selectedEncoding: selectedEncoding);
}
