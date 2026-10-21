import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/core/file_access/studio_file_identity.dart';
import 'package:subtitle_studio/utils/saf_file_handler.dart';

void main() {
  test('URI-only video selection keeps the real Android document locator', () {
    const document =
        'content://media.example/document/primary%3AMovies%2Flarge.mkv';
    const display = '/storage/emulated/0/Movies/large.mkv';
    const picked = SafFileInfo(uri: document, displayPath: display);

    final reference = picked.pickedReference(isFromSaf: true);
    expect(picked.content, isNull); // Selecting a large video reads no bytes.
    expect(reference.accessLocator, document);
    expect(reference.displayPath, display);
    expect(reference.isFromSaf, isTrue);
    expect(reference.identity.kind, StudioFileLocationKind.androidDocument);
    expect(reference.identity.canStatLocally, isFalse);
    expect(picked.toString(), isNot(contains(document)));
    expect(picked.toString(), isNot(contains(display)));
  });

  test('URI-only video selection preserves native Windows and Unix paths', () {
    for (final path in [r'C:\Videos\movie.mkv', '/data/videos/movie.mkv']) {
      final reference = SafFileInfo(uri: path, displayPath: path)
          .pickedReference(isFromSaf: false);
      expect(reference.accessLocator, path);
      expect(reference.identity.kind, StudioFileLocationKind.nativePath);
      expect(reference.isFromSaf, isFalse);
    }
  });

  test('URI-only video selection rejects display-path grant substitution', () {
    const display = '/storage/emulated/0/Movies/movie.mp4';
    for (final wrongUri in [
      display,
      'content://',
      'https://example.test/video.mp4?token=private',
    ]) {
      expect(
        () => SafFileInfo(uri: wrongUri, displayPath: display)
            .pickedReference(isFromSaf: true),
        throwsFormatException,
      );
    }
  });

  test('a remote URL or SAF document cannot impersonate native video path', () {
    for (final wrongUri in [
      'https://example.test/video.mp4',
      'content://media.example/document/1',
    ]) {
      expect(
        () => SafFileInfo(uri: wrongUri, displayPath: 'video.mp4')
            .pickedReference(isFromSaf: false),
        throwsFormatException,
      );
    }
  });
}
