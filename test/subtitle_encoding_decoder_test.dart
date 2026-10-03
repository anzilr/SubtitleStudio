import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_encoding_decoder.dart';

void main() {
  test('SubtitleEncodingDecoder reports UTF-8 for valid UTF-8 files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'subtitle_encoding_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final file = File(
      '${directory.path}${Platform.pathSeparator}sample.srt',
    );
    await file.writeAsBytes(
      utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nHello\n'),
    );

    final decoded = await SubtitleEncodingDecoder.decodeFile(file);

    expect(decoded.encoding, 'UTF-8');
    expect(decoded.content, contains('Hello'));
  });
}
