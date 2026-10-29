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
