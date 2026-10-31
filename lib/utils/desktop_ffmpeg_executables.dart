import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

/// Finds the portable FFmpeg tools installed alongside the Windows executable.
///
/// A developer's PATH installation remains a fallback, and other desktop
/// platforms keep using their existing system tools. No PATH changes or
/// elevation are required for the packaged Windows application.
class DesktopFfmpegExecutables {
  const DesktopFfmpegExecutables._();

  static String ffmpeg() => resolve('ffmpeg');

  static String ffprobe() => resolve('ffprobe');

  /// Only identify the known media-dependency failure signature. Do not show
  /// arbitrary exception text because it may contain the user's video path.
  static bool isMissingToolsError(Object error) {
    final message = error.toString();
    return message.contains('FFmpeg or FFprobe is unavailable') ||
        message.contains('FFmpeg is not available');
  }

  /// Windows installers ship both tools; Linux uses the system PATH.
  static String missingToolsGuidance({required bool isWindows}) {
    if (isWindows) {
      return 'Video subtitle extraction requires FFmpeg and FFprobe. '
          'Repair or reinstall SubtitleStudio to restore the bundled media '
          'tools. For a portable development build, install both tools '
          'and make them available on PATH.';
    }
    return 'Video subtitle extraction requires FFmpeg and FFprobe installed '
        'and available on your system PATH.';
  }

  /// Injectable inputs keep Windows path lookup testable on other hosts.
  static String resolve(
    String tool, {
    bool? isWindows,
    String? executablePath,
    bool Function(String)? fileExists,
  }) {
    if (tool != 'ffmpeg' && tool != 'ffprobe') {
      throw ArgumentError.value(tool, 'tool', 'Unsupported media executable');
    }

    if (!(isWindows ?? Platform.isWindows)) return tool;

    final appExe = executablePath ?? Platform.resolvedExecutable;
    final bundled = path.windows.join(
      path.windows.dirname(appExe),
      'tools',
      'ffmpeg',
      'bin',
      '$tool.exe',
    );
    if ((fileExists ?? (candidate) => File(candidate).existsSync())(bundled)) {
      return bundled;
    }
    return tool;
  }
}
