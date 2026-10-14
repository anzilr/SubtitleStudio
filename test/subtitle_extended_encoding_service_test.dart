import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/subtitle_extended_encoding_service.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

/// In-memory native adapter with real, independently known legacy charset
/// fixture bytes. Tests run without native platform method channels.
class FixtureBackend implements SubtitleCharsetBackend {
  bool substitute = false;
  final Map<String, Map<String, List<int>>> tables = {
    'windows-1250': {'Č': [0xC8]},
    'windows-1251': {'Я': [0xDF]},
    'windows-1256': {'م': [0xE3]},
    'Shift_JIS': {'日': [0x93, 0xFA]},
    'EUC-KR': {'한': [0xC7, 0xD1]},
    'GB18030': {'中': [0xD6, 0xD0]},
  };

  @override
  Future<bool> available(String name) async => tables.containsKey(name);

  @override
  Future<Uint8List> encode(String name, String text) async {
    final codepoints = tables[name] ?? {};
    final out = <int>[];
    for (final scalar in text.runes) {
      if (scalar < 128) {
        out.add(scalar);
        continue;
      }
      final bytes = codepoints[String.fromCharCode(scalar)];
      if (bytes == null) {
        if (!substitute) {
          throw const FormatException('Unsupported character');
        }
        out.add(0x3F);
      } else {
        out.addAll(bytes);
      }
    }
    return Uint8List.fromList(out);
  }

  @override
  Future<String> decode(String name, Uint8List bytes) async {
    final codepoints = tables[name] ?? {};
    final out = StringBuffer();
    var index = 0;
    while (index < bytes.length) {
      if (bytes[index] < 128) {
        out.writeCharCode(bytes[index++]);
        continue;
      }
      var matched = false;
      for (final entry in codepoints.entries) {
        final pattern = entry.value;
        if (index + pattern.length > bytes.length) continue;
        var isMatch = true;
        for (var j = 0; j < pattern.length; j++) {
          if (pattern[j] != bytes[index + j]) isMatch = false;
        }
        if (isMatch) {
          out.write(entry.key);
          index += pattern.length;
          matched = true;
          break;
        }
      }
      if (!matched) {
        if (!substitute) {
          throw const FormatException('Unsupported byte sequence');
        }
        out.write('?');
        index++;
      }
    }
    return out.toString();
  }
}

SubtitleLine _line(String text) => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = text
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

void main() {
  test('catalog includes broad script families but only advertises '
      'supported bidirectional codecs', () async {
    final backend = FixtureBackend();
    final service = SubtitleExtendedEncodingService(backend: backend);
    final list = await service.availableEncodings();
    expect(list, containsAll(SubtitleTextCodec.supportedEncodings));
    expect(list, containsAll([
      'Windows-1250', 'Windows-1251', 'Windows-1256',
      'Shift_JIS', 'EUC-KR', 'GB18030',
    ]));
    expect(list, isNot(contains('Big5')));
    expect(list, isNot(contains('ISO-8859-3')));
    expect(list.length, SubtitleTextCodec.supportedEncodings.length + 6);
    expect(SubtitleExtendedEncodingService.extendedEncodings.length, 58);
    expect(SubtitleExtendedEncodingService.canonical('cp1251'),
        'Windows-1251');
    expect(SubtitleExtendedEncodingService.canonical('shift-jis'),
        'Shift_JIS');
    expect(SubtitleExtendedEncodingService.canonical('CP936'), 'GBK');
    expect(() => SubtitleExtendedEncodingService.canonical('fake-codec'),
        throwsUnsupportedError);
  });

  test('regional single- and multibyte fixture decoding, strict roundtrip',
      () async {
    final service = SubtitleExtendedEncodingService(
      backend: FixtureBackend());
    final cases = <(String, String, List<int>)>[
      ('Windows-1250', 'Č', [0xC8]),
      ('Windows-1251', 'Я', [0xDF]),
      ('Windows-1256', 'م', [0xE3]),
      ('Shift_JIS', '日', [0x93, 0xFA]),
      ('EUC-KR', '한', [0xC7, 0xD1]),
      ('GB18030', '中', [0xD6, 0xD0]),
    ];
    for (final (encoding, text, bytes) in cases) {
      final decoded = await service.decode(bytes,
          selectedEncoding: encoding);
      expect(decoded.content, text, reason: encoding);
      expect(decoded.encoding, encoding);
      final encoded = await service.encode(text, encoding: encoding);
      expect(encoded, bytes, reason: encoding);
      final srtBytes = await SrtCompiler.generateSrtBytesExtended(
          [_line(text)], encoding: encoding, service: service);
      final output = await service.decode(srtBytes,
          selectedEncoding: encoding);
      expect(SubtitleParser.parseSrt(output.content).single.text, text);
    }
  });

  test('native substitution, unrecognized bytes and BOM conflicts fail',
      () async {
    final backend = FixtureBackend()..substitute = true;
    final service = SubtitleExtendedEncodingService(backend: backend);
    await expectLater(
      service.encode('😀', encoding: 'Windows-1251'),
      throwsFormatException,
    );
    await expectLater(
      service.decode([0xDF, 0xFE], selectedEncoding: 'Windows-1251'),
      throwsFormatException,
    );
    await expectLater(
      service.decode([0xFF, 0xFE, 0x41, 0],
          selectedEncoding: 'Windows-1256'),
      throwsFormatException,
    );
    await expectLater(
      service.encode('Hi', encoding: 'Big5'),
      throwsUnsupportedError,
    );
  });

  test('portable codecs still work without a registered plugin', () async {
    final service = SubtitleExtendedEncodingService(
      backend: FixtureBackend());
    final bytes = await service.encode('മലയാളം 😀',
      encoding: 'UTF-8 BOM');
    final decoded = await service.decode(bytes);
    expect(decoded.encoding, 'UTF-8 BOM');
    expect(decoded.content, 'മലയാളം 😀');
  });
}
