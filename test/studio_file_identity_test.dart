import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';

void main() {
  test('native Windows, UNC, POSIX and relative paths stay byte-identical', () {
    for (final source in <String>[
      r'C:\Video\Movie.mkv',
      r'C:Relative\name.srt',
      r'\\server\share\movie.mkv',
      '/home/demo/subtitle.srt',
      '../subtitles/name.srt',
      'my movie.srt',
    ]) {
      final identity = StudioFileIdentity.fromLocator(source);
      expect(identity.kind, StudioFileLocationKind.nativePath);
      expect(identity.canStatLocally, isTrue);
      expect(identity.persistedLocator, source);
      expect(identity.isAndroidDocument, isFalse);
      expect(identity.toString(), isNot(contains(source)));
    }
  });

  test('SAF documents retain exact provider identity without exposing it', () {
    const source =
        'content://com.android.externalstorage.documents/document/primary%3AMovie.mkv';
    final identity = StudioFileIdentity.fromLocator(source);
    expect(identity.kind, StudioFileLocationKind.androidDocument);
    expect(identity.isAndroidDocument, isTrue);
    expect(identity.canStatLocally, isFalse);
    expect(identity.persistedLocator, source);
    expect(identity.toString(), isNot(contains('Movie')));
    expect(identity, StudioFileIdentity.fromLocator(source));
    expect(identity.hashCode, StudioFileIdentity.fromLocator(source).hashCode);
    expect(identity, isNot(StudioFileIdentity.fromLocator(
        'content://com.android.externalstorage.documents/document/other')));
  });

  test('URI source types never pretend to be native files', () {
    for (final source in <String>[
      'https://example.org/videos/test.mkv?key=secret',
      'rtsp://example.org/video',
      'file:///tmp/test.srt',
      'saf:1.mkv',
    ]) {
      final id = StudioFileIdentity.fromLocator(source);
      expect(id.canStatLocally, isFalse);
      expect(id.persistedLocator, source);
      expect(id.toString(), isNot(contains(source)));
    }
    expect(StudioFileIdentity.fromLocator('file:///tmp/test.srt').kind,
        StudioFileLocationKind.fileUri);
    expect(StudioFileIdentity.fromLocator('https://example.org').kind,
        StudioFileLocationKind.remoteUri);
    expect(StudioFileIdentity.fromLocator('saf:1.mkv').kind,
        StudioFileLocationKind.opaqueUri);
  });

  test('rejects absent or malformed Android SAF identities without path leaks', () {
    for (final bad in ['', ' ', '\n', 'content://', 'content:/document/1']) {
      expect(() => StudioFileIdentity.fromLocator(bad), throwsFormatException);
    }
  });
}
