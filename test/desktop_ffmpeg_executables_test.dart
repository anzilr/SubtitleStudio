import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/desktop_ffmpeg_executables.dart';

void main() {
  test('Windows release prefers bundled FFmpeg in its own installation', () {
    const expected =
        r'C:\Program Files\SubtitleStudio\tools\ffmpeg\bin\ffmpeg.exe';
    final resolved = DesktopFfmpegExecutables.resolve(
      'ffmpeg',
      isWindows: true,
      executablePath: r'C:\Program Files\SubtitleStudio\SubtitleStudio.exe',
      fileExists: (candidate) => candidate == expected,
    );
    expect(resolved, expected);
  });

  test('FFprobe uses the same bundled location, including spaces', () {
    const expected =
        r'D:\Subtitle Studio\tools\ffmpeg\bin\ffprobe.exe';
    expect(
      DesktopFfmpegExecutables.resolve(
        'ffprobe',
        isWindows: true,
        executablePath: r'D:\Subtitle Studio\SubtitleStudio.exe',
        fileExists: (candidate) => candidate == expected,
      ),
      expected,
    );
  });

  test('falls back to system executable when bundle is absent', () {
    expect(
      DesktopFfmpegExecutables.resolve(
        'ffmpeg',
        isWindows: true,
        executablePath: r'C:\App\SubtitleStudio.exe',
        fileExists: (_) => false,
      ),
      'ffmpeg',
    );
  });

  test('other desktop platforms retain their existing PATH behavior', () {
    expect(
      DesktopFfmpegExecutables.resolve(
        'ffprobe',
        isWindows: false,
        executablePath: '/usr/bin/subtitle_studio',
        fileExists: (_) => true,
      ),
      'ffprobe',
    );
  });

  test('recognizes current and legacy FFmpeg availability errors', () {
    expect(
      DesktopFfmpegExecutables.isMissingToolsError(
        Exception('FFmpeg or FFprobe is unavailable.'),
      ),
      isTrue,
    );
    expect(
      DesktopFfmpegExecutables.isMissingToolsError(
        Exception('FFmpeg is not available'),
      ),
      isTrue,
    );
    expect(
      DesktopFfmpegExecutables.isMissingToolsError(
        Exception('Cannot read a private video file'),
      ),
      isFalse,
    );
  });

  test('dependency guidance matches bundled Windows and system Linux tools',
      () {
    final windows = DesktopFfmpegExecutables.missingToolsGuidance(
      isWindows: true,
    );
    final linux = DesktopFfmpegExecutables.missingToolsGuidance(
      isWindows: false,
    );
    expect(windows, contains('Repair or reinstall SubtitleStudio'));
    expect(windows, contains('bundled media'));
    expect(linux, contains('system PATH'));
    expect(linux, isNot(contains('reinstall SubtitleStudio')));
  });

  test('rejects arbitrary tool names', () {
    expect(
      () => DesktopFfmpegExecutables.resolve('../malicious', isWindows: true),
      throwsArgumentError,
    );
  });
}
