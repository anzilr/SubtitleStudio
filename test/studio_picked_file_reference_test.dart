import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/studio_picked_file_reference.dart';
import 'package:subtitle_studio/utils/platform_file_handler.dart';

void main() {
  test('SAF identity remains URI despite a display-style path', () {
    const uri = 'content://provider.example/document/primary%3AMovies%2Fsub.srt';
    const pretendPath = '/storage/emulated/0/Movies/sub.srt';
    final info = PlatformFileInfo(path: pretendPath,
      content: Uint8List.fromList([49, 10]), isFromSaf: true, safUri: uri);
    final selected = info.pickedReference;
    expect(selected.isFromSaf, isTrue);
    expect(selected.accessLocator, uri);
    expect(selected.displayPath, pretendPath);
    expect(selected.identity.canStatLocally, isFalse);
    final map = selected.toLegacyPickerInfo(info.content);
    expect(map['displayPath'], pretendPath);
    expect(map['safUri'], uri);
    expect(map['accessLocator'], uri);
    expect(map['bytes'], [49, 10]);
    expect(selected.toString(), isNot(contains('provider.example')));
    expect(info.toString(), isNot(contains(pretendPath)));
  });

  test('native picker returns unchanged path and legacy keys', () {
    const path = r'C:\Studio\subtitles\example.srt';
    final info = PlatformFileInfo(path: path,
      content: Uint8List(0), isFromSaf: false);
    final selected = info.pickedReference;
    expect(selected.accessLocator, path);
    expect(selected.identity.canStatLocally, isTrue);
    final map = selected.toLegacyPickerInfo(info.content);
    expect(map['displayPath'], path);
    expect(map['accessLocator'], path);
    expect(map['safUri'], isNull);
  });

  test('missing and malformed SAF grants fail closed', () {
    for (final bad in [null, 'content://',
      '/storage/emulated/0/Movies/sub.srt',
      'https://site.example/?secret=1']) {
      final info = PlatformFileInfo(path: 'sub.srt',
        content: Uint8List(0), isFromSaf: true, safUri: bad);
      expect(() => info.pickedReference, throwsFormatException);
    }
  });

  test('remote or document source cannot impersonate native picker', () {
    for (final value in [
      'https://example.net/sub.srt?private=1',
      'content://provider/document/id',
    ]) {
      expect(() => StudioPickedFileReference.fromPicker(
        accessLocator: value, displayPath: 'subtitle.srt',
        isFromSaf: false), throwsFormatException);
    }
  });

  test('empty display hint cannot produce an ambiguous selection', () {
    expect(() => StudioPickedFileReference.fromPicker(
      accessLocator: 'content://provider/document/id',
      displayPath: ' ', isFromSaf: true), throwsFormatException);
  });
}
