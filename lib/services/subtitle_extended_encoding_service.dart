import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'subtitle_text_codec.dart';

/// Injectable platform adapter: isolate native charset converters in tests.
abstract class SubtitleCharsetBackend {
  Future<bool> available(String name);
  Future<String> decode(String name, Uint8List bytes);
  Future<Uint8List> encode(String name, String text);
}

class NativeSubtitleCharsetBackend implements SubtitleCharsetBackend {
  const NativeSubtitleCharsetBackend();
  @override
  Future<bool> available(String name) => CharsetConverter.checkAvailability(name);
  @override
  Future<String> decode(String name, Uint8List bytes) =>
      CharsetConverter.decode(name, bytes);
  @override
  Future<Uint8List> encode(String name, String text) =>
      CharsetConverter.encode(name, text);
}

/// Dynamic extension of the portable codec: expose each charset only after
/// the installed OS converter passes a bidirectional capability probe.
///
/// Catalogue follows the broad families in Subtitle Composer/Subtitle Edit.
/// The existing SubtitleTextCodec remains the portable, synchronous tier.
class SubtitleExtendedEncodingService {
  final SubtitleCharsetBackend backend;
  const SubtitleExtendedEncodingService({
    this.backend = const NativeSubtitleCharsetBackend(),
  });
  static const standard = SubtitleExtendedEncodingService();

  static const List<String> extendedEncodings = [
    'Windows-1250', 'Windows-1251', 'Windows-1253', 'Windows-1254',
    'Windows-1255', 'Windows-1256', 'Windows-1257', 'Windows-1258',
    'ISO-8859-2', 'ISO-8859-3', 'ISO-8859-4', 'ISO-8859-5',
    'ISO-8859-6', 'ISO-8859-7', 'ISO-8859-8', 'ISO-8859-9',
    'ISO-8859-10', 'ISO-8859-11', 'ISO-8859-13', 'ISO-8859-14',
    'ISO-8859-15', 'ISO-8859-16',
    'KOI8-R', 'KOI8-U',
    'IBM437', 'IBM850', 'IBM852', 'IBM855', 'IBM866', 'IBM874',
    'Macintosh', 'Shift_JIS', 'EUC-JP', 'ISO-2022-JP',
    'EUC-KR', 'GBK', 'GB18030', 'Big5', 'Big5-HKSCS', 'TIS-620',
    'IBM737', 'IBM775', 'IBM857', 'IBM860', 'IBM861', 'IBM862',
    'IBM863', 'IBM864', 'IBM865', 'IBM869',
    'MacCyrillic', 'MacGreek', 'MacTurkish', 'MacCentralEurope',
    'GB2312', 'EUC-TW', 'HZ-GB-2312', 'ISO-2022-KR',
  ];

  static const Map<String, List<String>> _specialAliases = {
    'Shift_JIS': ['Shift_JIS', 'Shift-JIS', 'SJIS', 'MS932'],
    'EUC-JP': ['EUC-JP', 'EUC_JP'],
    'ISO-2022-JP': ['ISO-2022-JP', 'ISO2022JP'],
    'EUC-KR': ['EUC-KR', 'CP949'],
    'GBK': ['GBK', 'CP936'],
    'GB18030': ['GB18030', 'GB-18030'],
    'Big5': ['Big5', 'CP950'],
    'Big5-HKSCS': ['Big5-HKSCS', 'BIG5_HKSCS'],
    'TIS-620': ['TIS-620', 'TIS620', 'ISO-8859-11'],
    'Macintosh': ['macintosh', 'x-mac-roman', 'mac-roman'],
    'MacCyrillic': ['x-mac-cyrillic', 'mac-cyrillic', 'MacCyrillic'],
    'MacGreek': ['x-mac-greek', 'mac-greek', 'MacGreek'],
    'MacTurkish': ['x-mac-turkish', 'mac-turkish', 'MacTurkish'],
    'MacCentralEurope': ['x-mac-ce', 'mac-centraleurope', 'MacCentralEurope'],
    'GB2312': ['GB2312', 'GB_2312', 'EUC-CN'],
    'EUC-TW': ['EUC-TW', 'EUC_TW'],
    'HZ-GB-2312': ['HZ-GB-2312', 'HZ'],
    'ISO-2022-KR': ['ISO-2022-KR', 'ISO2022KR'],
  };

  static String canonical(String label) {
    try {
      return SubtitleTextCodec.canonical(label);
    } on UnsupportedError {
      final key = label.trim().toUpperCase()
          .replaceAll('_', '-').replaceAll(' ', '');
      for (final item in extendedEncodings) {
        if (key == item.toUpperCase().replaceAll('_', '-')) return item;
      }
      if (key.startsWith('CP') && key.length == 6) {
        final candidate = 'Windows-' + key.substring(2);
        if (extendedEncodings.contains(candidate)) return candidate;
      }
      const alternatives = {
        'SJIS': 'Shift_JIS', 'SHIFT-JIS': 'Shift_JIS',
        'MS932': 'Shift_JIS', 'CP932': 'Shift_JIS',
        'CP936': 'GBK', 'CP950': 'Big5', 'CP949': 'EUC-KR',
        'BIG-5': 'Big5', 'MAC-ROMAN': 'Macintosh',
        'X-MAC-ROMAN': 'Macintosh',
      };
      final candidate = alternatives[key];
      if (candidate != null) return candidate;
      throw UnsupportedError('Unknown source encoding: ' + label);
    }
  }

  static List<String> _namesFor(String name) {
    final special = _specialAliases[name];
    if (special != null) return special;
    if (name.startsWith('Windows-')) {
      final number = name.substring(8);
      return [name.toLowerCase(), 'windows' + number, 'cp' + number];
    }
    if (name.startsWith('IBM')) {
      final number = name.substring(3);
      return [name, 'CP' + number, number];
    }
    return [name, name.replaceAll('-', '')];
  }

  static String _probeFor(String name) {
    if (name == 'Windows-1251' || name == 'KOI8-R' ||
        name == 'KOI8-U' || name == 'IBM866' ||
        name == 'ISO-8859-5' || name == 'MacCyrillic') return 'Я';
    if (name == 'Windows-1256' || name == 'ISO-8859-6' ||
        name == 'IBM864') return 'م';
    if (name == 'Windows-1255' || name == 'ISO-8859-8' ||
        name == 'IBM862') return 'א';
    if (name == 'Windows-1253' || name == 'ISO-8859-7' ||
        name == 'IBM737' || name == 'IBM869' ||
        name == 'MacGreek') return 'Ω';
    if (name == 'Windows-1250' || name == 'ISO-8859-2' ||
        name == 'IBM852' || name == 'MacCentralEurope') return 'Č';
    if (name == 'Windows-1254' || name == 'ISO-8859-9' ||
        name == 'IBM857' || name == 'MacTurkish') return 'Ğ';
    if (name == 'TIS-620' || name == 'ISO-8859-11' ||
        name == 'IBM874') return 'ก';
    if (name == 'Shift_JIS' || name == 'EUC-JP' ||
        name == 'ISO-2022-JP') return '日';
    if (name == 'EUC-KR' || name == 'ISO-2022-KR') return '한';
    if (name == 'GBK' || name == 'GB18030' ||
        name == 'Big5' || name == 'Big5-HKSCS' ||
        name == 'GB2312' || name == 'EUC-TW' ||
        name == 'HZ-GB-2312') return '中';
    if (name == 'IBM775') return 'Ē';
    if (name == 'IBM860') return 'ã';
    if (name == 'IBM861') return 'Þ';
    // Every remaining 8-bit alias must demonstrate a non-ASCII roundtrip,
    // not merely report that its ASCII subset is available.
    return 'é';
  }

  /// Validates that a candidate can encode AND decode its script probe.
  Future<String?> _resolve(String name) async {
    for (final alias in _namesFor(name)) {
      try {
        if (!await backend.available(alias)) continue;
        final probe = _probeFor(name);
        final bytes = await backend.encode(alias, probe);
        final decoded = await backend.decode(alias, bytes);
        if (decoded == probe && bytes.isNotEmpty) return alias;
      } catch (_) {
        // Platform lacks the alias or native plugin is not registered.
      }
    }
    return null;
  }

  Future<List<String>> availableEncodings() async {
    final results = await Future.wait(extendedEncodings.map((name) async {
      return await _resolve(name) == null ? null : name;
    }));
    return List<String>.unmodifiable([
      ...SubtitleTextCodec.supportedEncodings, ...results.whereType<String>(),
    ]);
  }

  Future<DecodedSubtitleContent> decode(List<int> bytes,
      {String? selectedEncoding}) async {
    if (selectedEncoding == null) return SubtitleTextCodec.decode(bytes);
    final name = canonical(selectedEncoding);
    if (SubtitleTextCodec.supportedEncodings.contains(name)) {
      return SubtitleTextCodec.decode(bytes, selectedEncoding: name);
    }
    if (_hasUnicodeBom(bytes)) {
      throw const FormatException(
        'Unicode BOM conflicts with the chosen legacy encoding.');
    }
    final alias = await _resolve(name);
    if (alias == null) {
      throw UnsupportedError(name + ' is unavailable for bidirectional '
          'conversion on this platform.');
    }
    final input = Uint8List.fromList(bytes);
    final text = await backend.decode(alias, input);
    final output = await backend.encode(alias, text);
    if (!_equal(input, output)) {
      throw FormatException(name + ' cannot decode the source bytes '
          'without substitution. Choose another encoding.');
    }
    return DecodedSubtitleContent(content: text, encoding: name);
  }

  Future<Uint8List> encode(String text, {required String encoding}) async {
    final name = canonical(encoding);
    if (SubtitleTextCodec.supportedEncodings.contains(name)) {
      return SubtitleTextCodec.encode(text, encoding: name);
    }
    final alias = await _resolve(name);
    if (alias == null) {
      throw UnsupportedError(name + ' is unavailable for bidirectional '
          'conversion on this platform.');
    }
    final bytes = await backend.encode(alias, text);
    if (await backend.decode(alias, bytes) != text) {
      throw FormatException('The text is not representable in ' + name +
          ' without replacement. Choose UTF-8.');
    }
    return bytes;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _hasUnicodeBom(List<int> b) {
    if (b.length >= 2 &&
        ((b[0] == 0xFF && b[1] == 0xFE) ||
         (b[0] == 0xFE && b[1] == 0xFF))) return true;
    if (b.length >= 3 && b[0] == 0xEF &&
        b[1] == 0xBB && b[2] == 0xBF) return true;
    return b.length >= 4 &&
        ((b[0] == 0 && b[1] == 0 && b[2] == 0xFE && b[3] == 0xFF) ||
         (b[0] == 0xFF && b[1] == 0xFE && b[2] == 0 && b[3] == 0));
  }
}
