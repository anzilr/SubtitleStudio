import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

/// Resolves portable FFmpeg tools inside a desktop application's own bundle.
///
/// Windows packages use tools/ffmpeg/bin next to the executable. macOS
/// packages use Contents/Resources/tools/ffmpeg/bin inside the .app. Developer
/// and Linux installations can still fall back to executables on PATH.
/// No PATH modifications, elevated privileges or Homebrew are required.
class DesktopFfmpegExecutables {
  const DesktopFfmpegExecutables._();

  static String ffmpeg() => resolve('ffmpeg');

  static String ffprobe() => resolve('ffprobe');

  /// Never expose raw process errors: they can contain private video paths.
  static bool isMissingToolsError(Object error) {
    final message = error.toString();
    return message.contains('FFmpeg or FFprobe is unavailable') ||
        message.contains('FFmpeg is not available') ||
        message.contains('FFmpeg is unavailable');
  }

  static String missingToolsGuidance({
    required bool isWindows,
    bool isMacOS = false,
  }) {
    if (isWindows || isMacOS) {
      return 'Video subtitle extraction requires FFmpeg and FFprobe. '
          'Repair or reinstall SubtitleStudio to restore the bundled media '
          'tools. For a portable development build, install both tools '
          'and make them available on PATH.';
    }
    return 'Video subtitle extraction requires FFmpeg and FFprobe installed '
        'and available on your system PATH.';
  }

  /// Injectable platform and filesystem inputs make bundled paths testable
  /// without depending on the host architecture or operating system.
  static String resolve(
    String tool, {
    bool? isWindows,
    bool? isMacOS,
    String? executablePath,
    bool Function(String)? fileExists,
  }) {
    if (tool != 'ffmpeg' && tool != 'ffprobe') {
      throw ArgumentError.value(tool, 'tool', 'Unsupported media executable');
    }

    final windows = isWindows ?? Platform.isWindows;
    final macOS = isMacOS ?? Platform.isMacOS;
    if (!windows && !macOS) return tool;

    final appExe = executablePath ?? Platform.resolvedExecutable;
    final bundled = windows
        ? path.windows.join(
            path.windows.dirname(appExe),
            'tools',
            'ffmpeg',
            'bin',
            '$tool.exe',
          )
        : path.posix.normalize(path.posix.join(
            path.posix.dirname(appExe),
            '..',
            'Resources',
            'tools',
            'ffmpeg',
            'bin',
            tool,
          ));
    if ((fileExists ?? (candidate) => File(candidate).existsSync())(bundled)) {
      return bundled;
    }
    return tool;
  }
}
