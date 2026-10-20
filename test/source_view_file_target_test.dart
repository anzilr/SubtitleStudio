import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/screens/source_view/source_view_file_target.dart';

void main() {
  test('native source without SAF uses only the actual local path', () {
    for (final path in [
      '/storage/emulated/0/subtitles/demo.srt',
      r'C:\subtitles\demo.srt',
      r'\\nas\share\demo.srt',
      '../subtitles/demo.srt',
    ]) {
      final access = SourceViewFileTarget.resolve(filePath: path);
      expect(access.canFallbackToLocalFile, isTrue);
      expect(access.source.persistedLocator, path);
      expect(access.androidDocumentUri, isNull);
    }
  });

  test('existing native cache path retains explicit SAF grant preference', () {
    const cached = '/data/user/0/app/cache/source.srt';
    const provider = 'content://com.example.documents/document/a%3Ab.srt';
    final access = SourceViewFileTarget.resolve(
      filePath: cached, safUri: provider,
    );
    expect(access.source.persistedLocator, cached);
    expect(access.androidDocumentUri, provider);
    expect(access.canFallbackToLocalFile, isTrue);
  });

  test('direct Android document URI never becomes a native fallback', () {
    const provider = 'content://com.example.documents/document/a%3Ab.srt';
    final access = SourceViewFileTarget.resolve(filePath: provider);
    expect(access.androidDocumentUri, provider);
    expect(access.canFallbackToLocalFile, isFalse);
    expect(access.source.toString(), isNot(contains('a%3Ab')));
  });

  test('URI-based remote and opaque sources cannot use dart:io File', () {
    for (final locator in [
      'file:///tmp/file.srt',
      'https://example.com/srt?id=token',
      'saf:unknown-source',
      'rtsp://host/track',
    ]) {
      final access = SourceViewFileTarget.resolve(filePath: locator);
      expect(access.canFallbackToLocalFile, isFalse);
      expect(access.androidDocumentUri, isNull);
    }
  });

  test('malformed or misleading SAF grant fails closed', () {
    const source = '/tmp/source.srt';
    for (final grant in [
      'file:///tmp/unrelated.srt',
      'https://example.com/other.srt',
      'content://',
    ]) {
      expect(() => SourceViewFileTarget.resolve(
        filePath: source, safUri: grant,
      ), throwsFormatException);
    }
    expect(() => SourceViewFileTarget.resolve(filePath: ''),
        throwsFormatException);
  });
}
