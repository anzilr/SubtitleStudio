import 'subtitle_extended_encoding_service.dart';
import 'subtitle_text_codec.dart';

class SubtitleEncodingPreviewResult {
  final String encoding;
  final String text;
  final bool truncated;

  const SubtitleEncodingPreviewResult({
    required this.encoding,
    required this.text,
    required this.truncated,
  });
}

/// Decode through the identical strict import boundary, never through an
/// independently guessed preview charset. Limit UI text, not source bytes:
/// truncating multibyte input before decoding can split UTF-8/UTF-16.
class SubtitleEncodingPreview {
  final SubtitleExtendedEncodingService codec;

  const SubtitleEncodingPreview({
    this.codec = SubtitleExtendedEncodingService.standard,
  });

  Future<SubtitleEncodingPreviewResult> generate(
    List<int> bytes, {
    String? selectedEncoding,
    int maxCharacters = 500,
  }) async {
    if (maxCharacters < 1) {
      throw ArgumentError.value(maxCharacters, 'maxCharacters');
    }
    final DecodedSubtitleContent decoded = await codec.decode(
      bytes, selectedEncoding: selectedEncoding,
    );
    final runes = decoded.content.runes;
    final preview = runes.take(maxCharacters + 1).toList();
    final truncated = preview.length > maxCharacters;
    return SubtitleEncodingPreviewResult(
      encoding: decoded.encoding,
      text: String.fromCharCodes(
        truncated ? preview.take(maxCharacters) : preview,
      ),
      truncated: truncated,
    );
  }
}
