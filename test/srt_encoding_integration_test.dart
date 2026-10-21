import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/subtitle_encoding_decoder.dart';
import 'package:subtitle_studio/services/subtitle_text_codec.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';

SubtitleLine _entry(String text) => SubtitleLine()
  ..index = 1
  ..startTime = '00:00:01,000'
  ..endTime = '00:00:02,000'
  ..original = text
  ..edited = null
  ..marked = false
  ..comment = null
  ..resolved = false;

void main() {
  test('Unicode SRT compiles and parses across BOM profiles', () {
    const content = 'മലയാളം\nالعربية 😀';
    for (final encoding in ['UTF-8', 'UTF-8 BOM',
      'UTF-16LE BOM', 'UTF-16BE BOM', 'UTF-16LE', 'UTF-16BE']) {
      final output = SrtCompiler.generateSrtBytes(
        [_entry(content)], encoding: encoding);
      final decoded = SubtitleEncodingDecoder.decodeBytes(output,
        selectedEncoding: encoding.endsWith(' BOM') ? null : encoding);
      final parsed = SubtitleParser.parseSrt(decoded.content);
      expect(parsed.length, 1);
      expect(parsed.single.text, content);
      expect(decoded.encoding, encoding);
      expect(SubtitleTextCodec.encode(decoded.content,
          encoding: decoded.encoding), output);
    }
  });

  test('Windows-1252 and Latin-1 export exactly the chosen byte codec', () {
    for (final choice in ['Windows-1252', 'ISO-8859-1']) {
      final text = choice == 'Windows-1252'
          ? 'Café “Hello”' : 'Café Noël';
      final output = SrtCompiler.generateSrtBytes(
        [_entry(text)], encoding: choice);
      final decoded = SubtitleTextCodec.decode(output,
        selectedEncoding: choice);
      expect(decoded.encoding, choice);
      expect(SubtitleParser.parseSrt(decoded.content).single.text, text);
      expect(SubtitleTextCodec.encode(decoded.content,
          encoding: choice), output);
    }
    expect(() => SrtCompiler.generateSrtBytes(
        [_entry('മലയാളം')], encoding: 'Windows-1252'),
        throwsFormatException);
    expect(() => SrtCompiler.generateSrtBytes(
        [_entry('😀')], encoding: 'ISO-8859-1'),
        throwsFormatException);
  });

  test('null edit uses original, explicit empty edit exports empty text', () {
    final unedited = _entry('Unchanged');
    final cleared = _entry('Private original')
      ..index = 2
      ..edited = '';
    final changed = _entry('Before')
      ..index = 3
      ..edited = 'After';

    final editedSrt = SrtCompiler.generateSrtContent([
      unedited, cleared, changed,
    ]);
    expect(editedSrt, contains('Unchanged'));
    expect(editedSrt, isNot(contains('Private original')));
    expect(editedSrt, contains('After'));
    expect(editedSrt, isNot(contains('Before')));
    final cues = SubtitleParser.parseSrt(editedSrt);
    expect(cues.map((cue) => cue.text), ['Unchanged', '', 'After']);

    final originalSrt = SrtCompiler.generateSrtContent([
      unedited, cleared, changed,
    ], forceOriginal: true);
    expect(originalSrt, contains('Private original'));
    expect(originalSrt, contains('Before'));
    expect(originalSrt, isNot(contains('After')));
  });

  test('desktop compilation matches the shared byte codec exactly', () async {
    final dir = await Directory.systemTemp.createTemp('srt_compile_equiv_');
    addTearDown(() => dir.delete(recursive: true));
    for (final label in ['UTF-8 BOM', 'UTF-16BE BOM', 'Windows-1252']) {
      final file = File('${dir.path}${Platform.pathSeparator}output.srt');
      final line = _entry('Original')..edited =
          label == 'Windows-1252' ? 'Café “new”' : 'മലയാളം 😀';
      final collection = SubtitleCollection(
        fileName: 'output.srt', filePath: file.path,
        encoding: label, lines: [line],
      );
      await SrtCompiler.compileSrt(collection);
      final expected = SrtCompiler.generateSrtBytes([line], encoding: label);
      expect(await file.readAsBytes(), orderedEquals(expected), reason: label);
      final content = SubtitleEncodingDecoder.decodeBytes(
        expected, selectedEncoding: label.endsWith(' BOM') ? null : label);
      expect(SubtitleParser.parseSrt(content.content).single.text,
          line.edited, reason: label);
    }
  });

  test('unrepresentable export leaves existing file and directories untouched',
      () async {
    final dir = await Directory.systemTemp.createTemp('srt_no_loss_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}existing.srt');
    final previous = SubtitleTextCodec.encode(
      'Old content', encoding: 'ISO-8859-1');
    await file.writeAsBytes(previous);
    final line = _entry('Original')..edited = 'മലയാളം';
    final collection = SubtitleCollection(
      fileName: 'existing.srt', filePath: file.path,
      encoding: 'ISO-8859-1', lines: [line],
    );

    await expectLater(SrtCompiler.compileSrt(collection), throwsException);
    expect(await file.readAsBytes(), orderedEquals(previous));
    final missingDirectory = Directory(
        '${dir.path}${Platform.pathSeparator}should-not-exist');
    final missingCollection = SubtitleCollection(
      fileName: 'missing.srt',
      filePath: '${missingDirectory.path}${Platform.pathSeparator}missing.srt',
      encoding: 'ISO-8859-1', lines: [line],
    );
    await expectLater(
        SrtCompiler.compileSrt(missingCollection), throwsException);
    expect(await missingDirectory.exists(), isFalse);
  });

  test('file larger than 5 MiB retains final bytes and encoding',
      () async {
    final dir = await Directory.systemTemp.createTemp('srt_codec_large_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(dir.path + Platform.pathSeparator + 'large.srt');
    final text = List.filled(5 * 1024 * 1024, 'a').join() + 'é';
    final input = SubtitleTextCodec.encode(text, encoding: 'UTF-8 BOM');
    await file.writeAsBytes(input);
    final decoded = await SubtitleEncodingDecoder.decodeFile(file);
    expect(decoded.encoding, 'UTF-8 BOM');
    expect(decoded.content, text);
    expect(SubtitleTextCodec.encode(decoded.content,
        encoding: decoded.encoding), input);
  });
}
