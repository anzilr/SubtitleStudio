import 'dart:convert';
import 'dart:typed_data';

class DecodedSubtitleContent {
  final String content;
  /// Canonical label, including source BOM choice where applicable.
  final String encoding;
  const DecodedSubtitleContent({required this.content, required this.encoding});
}

/// Portable byte codec for the same charset on subtitle import and export.
///
/// Autodetect accepts BOMs and strict UTF-8 only. A user must explicitly
/// choose an ambiguous legacy 8-bit encoding. No lossy conversion/fallback.
class SubtitleTextCodec {
  const SubtitleTextCodec._();

  static const List<String> supportedEncodings = [
    'UTF-8', 'UTF-8 BOM', 'UTF-16LE', 'UTF-16LE BOM',
    'UTF-16BE', 'UTF-16BE BOM', 'ASCII', 'ISO-8859-1',
    'Windows-1252',
  ];

  static const Map<int, int> _cp1252High = {
    0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
    0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6,
    0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152,
    0x8E: 0x017D, 0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C,
    0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014,
    0x98: 0x02DC, 0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A,
    0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
  };

  static String canonical(String label) {
    final key = label.trim().toUpperCase().replaceAll('_', '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    switch (key) {
      case 'UTF8':
      case 'UTF-8': return 'UTF-8';
      case 'UTF8 BOM':
      case 'UTF-8 BOM':
      case 'UTF-8 WITH BOM':
      case 'UTF-8-SIG': return 'UTF-8 BOM';
      case 'UTF-16':
      case 'UTF16':
      case 'UTF-16LE BOM':
      case 'UTF-16 LE BOM': return 'UTF-16LE BOM';
      case 'UTF-16BE BOM':
      case 'UTF-16 BE BOM': return 'UTF-16BE BOM';
      case 'UTF-16LE':
      case 'UTF-16 LE':
      case 'UTF16LE': return 'UTF-16LE';
      case 'UTF-16BE':
      case 'UTF-16 BE':
      case 'UTF16BE': return 'UTF-16BE';
      case 'US-ASCII':
      case 'ASCII': return 'ASCII';
      case 'LATIN1':
      case 'LATIN-1':
      case 'ISO8859-1':
      case 'ISO-8859-1': return 'ISO-8859-1';
      case 'CP1252':
      case 'WINDOWS-1252': return 'Windows-1252';
      default: throw UnsupportedError('Unsupported subtitle encoding: $label');
    }
  }

  static DecodedSubtitleContent decode(List<int> bytes,
      {String? selectedEncoding}) {
    final requested = selectedEncoding == null
        ? null : canonical(selectedEncoding);
    final data = Uint8List.fromList(bytes);
    if (_starts(data, const [0xFF, 0xFE, 0, 0]) ||
        _starts(data, const [0, 0, 0xFE, 0xFF])) {
      throw const FormatException('UTF-32 subtitle input is unsupported.');
    }
    final bomLabel = _starts(data, const [0xEF, 0xBB, 0xBF])
        ? 'UTF-8 BOM'
        : _starts(data, const [0xFF, 0xFE]) ? 'UTF-16LE BOM'
        : _starts(data, const [0xFE, 0xFF]) ? 'UTF-16BE BOM' : null;
    final label = requested ?? bomLabel ?? 'UTF-8';
    final withBom = label.endsWith(' BOM');
    final plain = withBom ? label.substring(0, label.length - 4) : label;
    if (bomLabel != null &&
        plain != bomLabel.substring(0, bomLabel.length - 4)) {
      throw const FormatException('Requested charset conflicts with BOM.');
    }
    if (withBom && bomLabel == null) {
      throw const FormatException('Selected encoding requires a BOM.');
    }
    final prefix = bomLabel == null ? 0 : bomLabel == 'UTF-8 BOM' ? 3 : 2;
    final payload = data.sublist(prefix);
    late String decoded;
    switch (plain) {
      case 'UTF-8':
        try {
          decoded = utf8.decode(payload, allowMalformed: false);
        } on FormatException {
          throw const FormatException(
              'Invalid UTF-8: select the source encoding explicitly.');
        }
        if (decoded.contains('\u0000')) {
          throw const FormatException(
              'NUL bytes detected; choose a UTF-16 encoding explicitly.');
        }
        break;
      case 'UTF-16LE':
      case 'UTF-16BE':
        if (payload.length.isOdd) {
          throw const FormatException('Truncated UTF-16 code unit.');
        }
        final units = <int>[];
        for (var i = 0; i < payload.length; i += 2) {
          units.add(plain == 'UTF-16LE'
              ? payload[i] | payload[i + 1] << 8
              : payload[i] << 8 | payload[i + 1]);
        }
        _validateUnits(units);
        decoded = String.fromCharCodes(units);
        break;
      case 'ASCII':
        if (payload.any((value) => value > 127)) {
          throw const FormatException('Non-ASCII byte in subtitle input.');
        }
        decoded = ascii.decode(payload);
        break;
      case 'ISO-8859-1':
        decoded = latin1.decode(payload);
        break;
      case 'Windows-1252':
        decoded = String.fromCharCodes(payload.map((value) {
          if (value >= 0x80 && value <= 0x9F) {
            final mapped = _cp1252High[value];
            if (mapped == null) {
              throw const FormatException('Undefined Windows-1252 byte.');
            }
            return mapped;
          }
          return value;
        }));
        break;
      default:
        throw UnsupportedError('Unsupported subtitle encoding: $label');
    }
    return DecodedSubtitleContent(
        content: decoded, encoding: bomLabel ?? label);
  }

  static Uint8List encode(String content, {required String encoding}) {
    final label = canonical(encoding);
    final bom = label.endsWith(' BOM');
    final plain = bom ? label.substring(0, label.length - 4) : label;
    _validateUnits(content.codeUnits);
    late List<int> bytes;
    switch (plain) {
      case 'UTF-8':
        bytes = utf8.encode(content);
        break;
      case 'UTF-16LE':
      case 'UTF-16BE':
        bytes = <int>[];
        for (final unit in content.codeUnits) {
          if (plain == 'UTF-16LE') {
            bytes.addAll([unit & 255, unit >> 8]);
          } else {
            bytes.addAll([unit >> 8, unit & 255]);
          }
        }
        break;
      case 'ASCII':
      case 'ISO-8859-1':
      case 'Windows-1252':
        final reverse1252 = {
          for (final e in _cp1252High.entries) e.value: e.key,
        };
        bytes = <int>[];
        for (final point in content.runes) {
          final int? value;
          if (plain == 'Windows-1252') {
            value = reverse1252[point] ??
                ((point < 128 || point >= 160 && point <= 255)
                    ? point : null);
          } else {
            value = point <= (plain == 'ASCII' ? 127 : 255) ? point : null;
          }
          if (value == null) {
            throw FormatException(
                'Text contains a character not representable in $label.');
          }
          bytes.add(value);
        }
        break;
      default:
        throw UnsupportedError('Unsupported subtitle encoding: $label');
    }
    final prefix = !bom ? const <int>[]
        : plain == 'UTF-8' ? const [0xEF, 0xBB, 0xBF]
        : plain == 'UTF-16LE' ? const [0xFF, 0xFE]
        : const [0xFE, 0xFF];
    return Uint8List.fromList([...prefix, ...bytes]);
  }

  static bool _starts(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static void _validateUnits(List<int> units) {
    for (var i = 0; i < units.length; i++) {
      final value = units[i];
      if (value >= 0xD800 && value <= 0xDBFF) {
        if (i + 1 == units.length ||
            units[i + 1] < 0xDC00 || units[i + 1] > 0xDFFF) {
          throw const FormatException('Unpaired UTF-16 high surrogate.');
        }
        i++;
      } else if (value >= 0xDC00 && value <= 0xDFFF) {
        throw const FormatException('Unpaired UTF-16 low surrogate.');
      }
    }
  }
}
