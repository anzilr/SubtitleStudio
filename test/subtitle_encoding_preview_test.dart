import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_encoding_preview.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

void main() {
  test('preview uses actual codec and preserves source BOM metadata', () async {
    final preview = const SubtitleEncodingPreview();
    for (final encoding in [
      'UTF-8 BOM', 'UTF-16LE BOM', 'UTF-16BE BOM',
    ]) {
      final bytes = SubtitleTextCodec.encode(
        'മലയാളം — العربية 😀', encoding: encoding);
      final result = await preview.generate(bytes);
      expect(result.encoding, encoding);
      expect(result.text, 'മലയാളം — العربية 😀');
      expect(result.truncated, isFalse);
    }
  });

  test('preview truncates decoded characters, not encoded bytes', () async {
    final bytes = SubtitleTextCodec.encode(
      '😀😀😀مലയാളം', encoding: 'UTF-16LE BOM');
    final result = await const SubtitleEncodingPreview().generate(
      bytes, maxCharacters: 2);
    expect(result.text, '😀😀');
    expect(result.truncated, isTrue);
    expect(result.encoding, 'UTF-16LE BOM');
  });

  test('preview fails on invalid legacy bytes until charset is selected',
      () async {
    final bytes = <int>[0x43, 0x61, 0x66, 0xE9];
    await expectLater(
      const SubtitleEncodingPreview().generate(bytes),
      throwsFormatException,
    );
    final result = await const SubtitleEncodingPreview().generate(
      bytes, selectedEncoding: 'ISO-8859-1');
    expect(result.text, 'Café');
    expect(result.encoding, 'ISO-8859-1');
  });

  test('preview rejects invalid size rather than creating broken UI', () async {
    await expectLater(
      const SubtitleEncodingPreview().generate(
        [65], maxCharacters: 0),
      throwsArgumentError,
    );
  });
}
