import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';

void main() {
  const sample = '1\r\n00:00:01,000 --> 00:00:02,000\r\n'
      'മലയാളം • العربية — “Café” 😀\r\n';

  test('UTF-8 with/without BOM is strict and byte-preserved', () {
    for (final encoding in ['UTF-8', 'UTF-8 BOM']) {
      final bytes = SubtitleTextCodec.encode(sample, encoding: encoding);
      final decoded = SubtitleTextCodec.decode(bytes);
      expect(decoded.encoding, encoding);
      expect(decoded.content, sample);
      expect(SubtitleTextCodec.encode(decoded.content,
          encoding: decoded.encoding), bytes);
    }
    expect(() => SubtitleTextCodec.decode([0x31, 0xC3]),
        throwsFormatException);
    expect(() => SubtitleTextCodec.decode([0x61, 0, 0x62]),
        throwsFormatException);
    expect(SubtitleTextCodec.decode(utf8.encode('Hi')).encoding, 'UTF-8');
  });

  test('UTF-16 endianness/BOM, emoji and CRLF survive roundtrips', () {
    for (final encoding in ['UTF-16LE BOM', 'UTF-16BE BOM',
                            'UTF-16LE', 'UTF-16BE']) {
      final bytes = SubtitleTextCodec.encode(sample, encoding: encoding);
      final decoded = SubtitleTextCodec.decode(bytes,
        selectedEncoding: encoding.endsWith(' BOM') ? null : encoding);
      expect(decoded.encoding, encoding);
      expect(decoded.content, sample);
      expect(SubtitleTextCodec.encode(decoded.content,
          encoding: decoded.encoding), bytes);
    }
    expect(() => SubtitleTextCodec.decode([0xFF, 0xFE, 0x31]),
        throwsFormatException);
    expect(() => SubtitleTextCodec.decode([0, 0, 0xFE, 0xFF]),
        throwsFormatException);
    expect(() => SubtitleTextCodec.decode([0xFF, 0xFE, 0, 0xD8]),
        throwsFormatException);
  });

  test('Latin-1 and Windows-1252 are distinct; exports are strict', () {
    final bytes = [0x43, 0x61, 0x66, 0xE9, 0x20, 0x93, 0x58, 0x94];
    final decoded = SubtitleTextCodec.decode(
      bytes, selectedEncoding: 'Windows-1252');
    expect(decoded.content, 'Café “X”');
    expect(SubtitleTextCodec.encode(decoded.content,
        encoding: decoded.encoding), bytes);
    expect(SubtitleTextCodec.decode([0x93],
      selectedEncoding: 'ISO-8859-1').content, '\u0093');
    expect(() => SubtitleTextCodec.decode([0x81],
      selectedEncoding: 'Windows-1252'), throwsFormatException);
    expect(() => SubtitleTextCodec.decode([0x93]), throwsFormatException);
    expect(() => SubtitleTextCodec.encode('€', encoding: 'ISO-8859-1'),
      throwsFormatException);
    expect(() => SubtitleTextCodec.encode('😀', encoding: 'Windows-1252'),
      throwsFormatException);
  });

  test('ASCII and unsupported charset do not silently fall back', () {
    expect(SubtitleTextCodec.encode('Test\n', encoding: 'ASCII'),
        [84, 101, 115, 116, 10]);
    expect(() => SubtitleTextCodec.encode('é', encoding: 'ASCII'),
        throwsFormatException);
    expect(() => SubtitleTextCodec.encode('Hi', encoding: 'Windows-1251'),
        throwsUnsupportedError);
    expect(() => SubtitleTextCodec.decode([0x80],
        selectedEncoding: 'Windows-1251'), throwsUnsupportedError);
    expect(SubtitleTextCodec.canonical('utf-8-sig'), 'UTF-8 BOM');
    expect(SubtitleTextCodec.canonical('UTF-16'), 'UTF-16LE BOM');
    expect(() => SubtitleTextCodec.encode(String.fromCharCode(0xD800),
        encoding: 'UTF-8'), throwsFormatException);
  });

  test('manual selection cannot contradict source BOM', () {
    expect(() => SubtitleTextCodec.decode([0xFF, 0xFE, 0x41, 0],
      selectedEncoding: 'UTF-8'), throwsFormatException);
    expect(() => SubtitleTextCodec.decode([0x41],
      selectedEncoding: 'UTF-8 BOM'), throwsFormatException);
    expect(SubtitleTextCodec.decode([0xEF, 0xBB, 0xBF, 0x41],
      selectedEncoding: 'UTF-8').encoding, 'UTF-8 BOM');
  });
}
