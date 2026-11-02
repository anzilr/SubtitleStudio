import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'dart:math' show min;
import 'package:subtitle_studio/utils/logging_helpers.dart';
import 'package:subtitle_studio/utils/ffmpeg_backend_policy.dart';

/// Interface for FFmpeg operations
abstract class FFmpegInterface {
  Future<List<Map<String, dynamic>>> getSubtitleTracks(String videoPath);
  Future<String> extractSubtitle(
    String videoPath,
    String outputPath,
    int streamIndex,
  );
  
  /// Enhanced method with track information for better filename generation
  Future<String> extractSubtitleWithTrackInfo(
    String videoPath,
    String outputPath,
    int streamIndex,
    Map<String, dynamic> trackInfo,
  );
  
  Future<double?> getVideoFramerate(String videoPath);
}

/// Native FFmpegKit backend shared by Android, iOS, macOS, Windows and Linux.
class NativeFFmpeg implements FFmpegInterface {
  
  /// Convert a file URI or mixed-separator path without exposing its contents.
  /// [operatingSystem] is injectable so desktop path rules remain testable
  /// without a Windows/macOS Flutter engine.
  static String convertToFilePath(
    String uriOrPath, {
    String? operatingSystem,
  }) {
    final currentPlatform = operatingSystem ?? Platform.operatingSystem;
    // If it's a file URI, convert it properly
    if (uriOrPath.startsWith('file://')) {
      try {
        final uri = Uri.parse(uriOrPath);
        return uri.toFilePath(windows: currentPlatform == 'windows');
      } catch (_) {
        if (kDebugMode) {
          print('Could not parse media file URI; using original locator');
        }
        // Fallback to removing file:// prefix
        return uriOrPath.replaceFirst('file://', '');
      }
    }
    
    if (currentPlatform == 'windows') {
      return uriOrPath.replaceAll('/', '\\');
    }

    // Android content:// locators are preserved for FFmpegKit SAF handling.
    // Unix targets use forward-slash separators.
    if (currentPlatform == 'android' ||
        currentPlatform == 'ios' ||
        currentPlatform == 'macos' ||
        currentPlatform == 'linux') {
      String normalizedPath = uriOrPath;
      
      // Convert any backslashes to forward slashes for Unix-style systems
      normalizedPath = normalizedPath.replaceAll('\\', '/');
      
      if (kDebugMode && normalizedPath != uriOrPath) {
        print('Normalized Unix-style media path separators');
      }
      
      return normalizedPath;
    }
    
    // Unsupported targets retain their locator; backend selection rejects them.
    return uriOrPath;
  }

  /// Convert SAF URI to FFmpeg-compatible parameter for reading
  static Future<String> _getSafReadableParameter(String filePath) async {
    if (Platform.isAndroid && filePath.startsWith('content://')) {
      try {
        // Use built-in SAF support from ffmpeg_kit_flutter_new
        final safParameter = await FFmpegKitConfig.getSafParameterForRead(
          filePath,
        );
        if (safParameter != null) {
          if (kDebugMode) {
            print('Converted SAF URI to FFmpeg input parameter');
          }
          return safParameter;
        } else {
          if (kDebugMode) {
            print('Could not convert SAF URI; using original locator');
          }
          return filePath;
        }
      } catch (_) {
        if (kDebugMode) {
          print('Could not convert SAF URI; using original locator');
        }
        return filePath;
      }
    }
    return filePath;
  }

  Future<List<Map<String, dynamic>>> getSubtitleTracks(String videoPath) async {
    try {
      if (kDebugMode) {
        print('Analyzing video subtitle tracks on ${Platform.operatingSystem}');
      }
      await logInfo('Starting subtitle track analysis on ${Platform.operatingSystem}');

      // For Android content URIs, use SAF parameter directly
      // For other paths, convert URI to proper file path if needed
      String ffmpegPath;
      if (Platform.isAndroid && videoPath.startsWith('content://')) {
        // Use SAF parameter for Android content URIs
        ffmpegPath = await _getSafReadableParameter(videoPath);
      } else {
        // Convert URI to proper file path for regular files
        ffmpegPath = convertToFilePath(videoPath);
      }
      
      if (kDebugMode) {
        print('Prepared FFprobe input locator');
      }

      final session = await FFprobeKit.getMediaInformation(ffmpegPath);
      final MediaInformation? mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        // Native FFprobe messages may include local paths and SAF parameters.
        final errorMsg = 'FFprobe did not return media information';
        await logError(errorMsg, context: 'NativeFFmpeg.getSubtitleTracks');
        throw Exception(errorMsg);
      }

      final streams = mediaInformation.getStreams();
      List<Map<String, dynamic>> subtitleTracks = [];

      int subtitleIndex = 0;
      for (var stream in streams) {
        final properties = stream.getAllProperties();
        if (properties?['codec_type'] == 'subtitle') {
          final streamIndex =
              int.tryParse(properties?['index'].toString() ?? '') ?? -1;
          subtitleTracks.add({
            'index': streamIndex,
            'codec': properties?['codec_name'] ?? 'unknown',
            'language': properties?['tags']?['language'] ?? 'und',
            'title': properties?['tags']?['title'] ?? 'Untitled',
            'subtitle_index': subtitleIndex,
          });
          subtitleIndex++;
        }
      }

      if (kDebugMode) {
        print('Found ${subtitleTracks.length} subtitle tracks');
      }

      return subtitleTracks;
    } catch (_) {
      if (kDebugMode) {
        print('Subtitle track analysis failed');
      }
      throw Exception('Failed to get subtitle tracks. Check media access and retry.');
    }
  }

  @override
  Future<String> extractSubtitle(
    String videoPath,
    String outputPath,
    int streamIndex,
  ) async {
    try {
      final videoFileName = FFmpegHelper.extractBaseFilename(videoPath);
      final outputFile = path.normalize(path.join(
        outputPath,
        '${videoFileName}_track$streamIndex.srt',
      ));

      if (kDebugMode) {
        print('Extracting subtitle on ${Platform.operatingSystem}');
        print('Stream index: $streamIndex');
      }

      // For Android content URIs, use SAF parameter directly
      // For other paths, convert URI to proper file path if needed
      String ffmpegPath;
      if (Platform.isAndroid && videoPath.startsWith('content://')) {
        // Use SAF parameter for Android content URIs
        ffmpegPath = await _getSafReadableParameter(videoPath);
      } else {
        // Convert URI to proper file path for regular files
        ffmpegPath = convertToFilePath(videoPath);
      }
      
      if (kDebugMode) {
        print('Prepared FFmpeg input locator');
      }

      // Check if input file exists and is readable (skip for content URIs and special paths)
      final videoFile = File(videoPath);
      if (!videoPath.startsWith('/proc/self/fd/') &&
          !videoPath.startsWith('content://') &&
          !await videoFile.exists()) {
        throw Exception('Input video file is unavailable');
      }

      // Check if output directory exists and is writable
      final outputDir = Directory(outputPath);
      if (!await outputDir.exists()) {
        if (kDebugMode) {
          print('Output directory does not exist; attempting to create it');
        }
        await outputDir.create(recursive: true);
      }

      // Try to create a test file to verify write permissions
      try {
        final testFile = File('$outputPath/test_write_permission.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
        if (kDebugMode) {
          print('Successfully verified write permissions for output directory');
        }
      } catch (_) {
        if (kDebugMode) {
          print('Output directory write check failed');
        }
        throw Exception('Cannot write to output directory');
      }

      // Build command - use FFmpeg-compatible path for SAF URIs
      final command =
          '-y -i "$ffmpegPath" -map 0:s:$streamIndex -c:s srt "$outputFile"';

      if (kDebugMode) {
        print('Executing FFmpeg subtitle extraction for stream $streamIndex');
      }

      // Delete existing file if it exists
      final outputFileObj = File(outputFile);
      if (await outputFileObj.exists()) {
        if (kDebugMode) {
          print('Deleting existing output file');
        }
        await outputFileObj.delete();
      }

      // Execute FFmpeg
      if (kDebugMode) {
        print('Starting FFmpeg process...');
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (kDebugMode) {
        print('FFmpeg execution completed');
        print('Return code: ${returnCode?.getValue() ?? "unknown"}');
      }

      if (returnCode == null) {
        throw Exception('FFmpeg process returned null code');
      }

      if (!returnCode.isValueSuccess()) {
        throw Exception('FFmpeg process failed with code ${returnCode.getValue()}');
      }

      // Verify the output file exists and has content
      await Future.delayed(
        const Duration(milliseconds: 1000),
      ); // Wait a bit for file system

      if (kDebugMode) {
        print('Checking whether FFmpeg created its output file');
      }
      
      if (!await outputFileObj.exists()) {
        throw Exception('Output file was not created after successful FFmpeg execution');
      }

      final fileSize = await outputFileObj.length();
      if (kDebugMode) {
        print('Output file size: $fileSize bytes');
      }

      if (fileSize == 0) {
        throw Exception('Output file was created but is empty (0 bytes)');
      }

      // Try to read the first few bytes to verify file is accessible
      try {
        final bytes =
            await outputFileObj.openRead(0, min(fileSize, 100)).toList();
        if (kDebugMode) {
          print('Successfully read ${bytes.length} bytes from output file');
        }
      } catch (_) {
        if (kDebugMode) {
          print('Output file readability check failed');
        }
        throw Exception('Output file exists but cannot be read');
      }

      return outputFile;
    } catch (_) {
      if (kDebugMode) {
        print('Subtitle extraction failed');
      }
      throw Exception('Failed to extract subtitle. Check media access and retry.');
    }
  }

  @override
  Future<String> extractSubtitleWithTrackInfo(
    String videoPath,
    String outputPath,
    int streamIndex,
    Map<String, dynamic> trackInfo,
  ) async {
    try {
      // Extract filename properly by handling both forward and back slashes
      String videoFileName = FFmpegHelper.extractBaseFilename(videoPath);
      
      // Generate better filename with language code or track number
      String trackIdentifier;
      final language = trackInfo['language'] as String?;
      final trackIndex = trackInfo['subtitle_index'] as int?;
      
      // Use language code if available and not "und" (undefined), otherwise use track number
      if (language != null && language.isNotEmpty && language != 'und') {
        trackIdentifier = language;
      } else {
        trackIdentifier = 'track${trackIndex ?? streamIndex}';
      }
      
      final outputFile = path.normalize(path.join(
        outputPath,
        '$videoFileName.$trackIdentifier.srt',
      ));

      if (kDebugMode) {
        print('Extracting subtitle on ${Platform.operatingSystem}');
        print('Stream index: $streamIndex');
      }

      // Check if output directory exists and is writable
      final outputDir = Directory(outputPath);
      if (!await outputDir.exists()) {
        if (kDebugMode) {
          print('Output directory does not exist; attempting to create it');
        }
        await outputDir.create(recursive: true);
      }

      // Try to create a test file to verify write permissions
      try {
        final testFile = File('$outputPath/test_write_permission.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
        if (kDebugMode) {
          print('Successfully verified write permissions for output directory');
        }
      } catch (_) {
        if (kDebugMode) {
          print('Output directory write check failed');
        }
        throw Exception('Cannot write to output directory');
      }

      // Convert URI to proper file path if needed, with SAF support for Android
      String ffmpegVideoPath;
      if (Platform.isAndroid && videoPath.startsWith('content://')) {
        // Use SAF parameter for Android content URIs
        ffmpegVideoPath = await _getSafReadableParameter(videoPath);
      } else {
        ffmpegVideoPath = convertToFilePath(videoPath);
      }
      
      final convertedOutputFile = convertToFilePath(outputFile);

      if (kDebugMode) {
        print('Prepared FFmpeg input and output locators');
      }

      // Delete existing file if it exists
      final outputFileObj = File(convertedOutputFile);
      if (await outputFileObj.exists()) {
        if (kDebugMode) {
          print('Deleting existing output file');
        }
        await outputFileObj.delete();
      }

      // Build command with proper path handling - use string format like old implementation
      final command = '-y -i "$ffmpegVideoPath" -map 0:s:$streamIndex -c:s srt "$convertedOutputFile"';

      if (kDebugMode) {
        print('Executing FFmpeg subtitle extraction for stream $streamIndex');
      }

      await logInfo('Starting FFmpeg subtitle extraction with track information');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (kDebugMode) {
        print('FFmpeg execution completed');
        print('Return code: ${returnCode?.getValue() ?? "unknown"}');
      }

      if (returnCode == null) {
        throw Exception('FFmpeg process returned null code');
      }

      if (!returnCode.isValueSuccess()) {
        throw Exception('FFmpeg process failed with code ${returnCode.getValue()}');
      }

      // Verify the output file exists and has content
      await Future.delayed(const Duration(milliseconds: 1000)); // Wait a bit for file system
      
      if (!await outputFileObj.exists()) {
        throw Exception('Output file was not created after successful FFmpeg execution');
      }

      final fileSize = await outputFileObj.length();
      if (kDebugMode) {
        print('Output file size: $fileSize bytes');
      }
      
      if (fileSize == 0) {
        throw Exception('Output file was created but is empty (0 bytes)');
      }

      // Try to read the first few bytes to verify file is accessible
      try {
        final bytes = await outputFileObj.openRead(0, min(fileSize, 100)).toList();
        if (kDebugMode) {
          print('Successfully read ${bytes.length} bytes from output file');
        }
      } catch (_) {
        if (kDebugMode) {
          print('Output file readability check failed');
        }
        throw Exception('Output file exists but cannot be read');
      }

      // Return the normalized output file path
      final normalizedOutputFile = FFmpegHelper.normalizePath(convertedOutputFile);
      await logInfo('Successfully extracted subtitle');
      return normalizedOutputFile;
    } catch (_) {
      await logError('Failed to extract subtitle with track information');
      if (kDebugMode) {
        print('Subtitle extraction with track information failed');
      }
      throw Exception('Failed to extract subtitle. Check media access and retry.');
    }
  }

  @override
  Future<double?> getVideoFramerate(String videoPath) async {
    try {
      if (kDebugMode) {
        print('Getting video framerate on ${Platform.operatingSystem}');
      }

      // Convert URI to proper file path if needed
      final convertedPath = convertToFilePath(videoPath);
      
      if (kDebugMode) {
        print('Prepared FFprobe input locator');
      }

      final session = await FFprobeKit.getMediaInformation(convertedPath);
      final MediaInformation? mediaInformation = session.getMediaInformation();

      if (mediaInformation == null) {
        if (kDebugMode) {
          print('FFprobe did not return media information');
        }
        return null;
      }

      final streams = mediaInformation.getStreams();

      // Find the video stream
      for (var stream in streams) {
        final properties = stream.getAllProperties();
        if (properties?['codec_type'] == 'video') {
          // First try to get the average framerate
          final avgFramerate = properties?['avg_frame_rate'];
          if (avgFramerate != null &&
              avgFramerate is String &&
              avgFramerate != '0/0') {
            try {
              // Parse fraction like "24000/1001" into a double
              final parts = avgFramerate.split('/');
              if (parts.length == 2) {
                final num = double.parse(parts[0]);
                final den = double.parse(parts[1]);
                if (den > 0) {
                  final fps = num / den;
                  if (kDebugMode) {
                    print('Detected video framerate: $fps fps');
                  }
                  return _normalizeFramerate(fps);
                }
              }
            } catch (_) {
              if (kDebugMode) {
                print('Could not parse average framerate');
              }
            }
          }

          // If average framerate didn't work, try r_frame_rate
          final rFramerate = properties?['r_frame_rate'];
          if (rFramerate != null &&
              rFramerate is String &&
              rFramerate != '0/0') {
            try {
              final parts = rFramerate.split('/');
              if (parts.length == 2) {
                final num = double.parse(parts[0]);
                final den = double.parse(parts[1]);
                if (den > 0) {
                  final fps = num / den;
                  if (kDebugMode) {
                    print('Detected video framerate (r_frame_rate): $fps fps');
                  }
                  return _normalizeFramerate(fps);
                }
              }
            } catch (_) {
              if (kDebugMode) {
                print('Could not parse r_frame_rate');
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('Could not determine framerate from video streams');
      }
      return null;
    } catch (_) {
      if (kDebugMode) {
        print('Video framerate detection failed');
      }
      return null;
    }
  }

  // Helper method to normalize common framerates to standard values
  double _normalizeFramerate(double fps) {
    // Round to 3 decimal places
    final rounded = double.parse(fps.toStringAsFixed(3));

    // Check for common framerates
    if ((rounded - 23.976).abs() < 0.01) return 23.976;
    if ((rounded - 24.0).abs() < 0.01) return 24.0;
    if ((rounded - 25.0).abs() < 0.01) return 25.0;
    if ((rounded - 29.97).abs() < 0.01) return 29.97;
    if ((rounded - 30.0).abs() < 0.01) return 30.0;
    if ((rounded - 50.0).abs() < 0.01) return 50.0;
    if ((rounded - 59.94).abs() < 0.01) return 59.94;
    if ((rounded - 60.0).abs() < 0.01) return 60.0;

    return rounded;
  }
}

/// Main FFmpegHelper class that selects the appropriate implementation based on platform
class FFmpegHelper implements FFmpegInterface {
  static FFmpegInterface? _instance;

  static FFmpegInterface get _implementation {
    _instance ??= _createImplementation();
    return _instance!;
  }

  /// Public method to normalize file paths for the current platform
  /// This ensures consistent path handling between FFmpegHelper and calling code
  static String normalizePath(String filePath) {
    if (!FfmpegKitPlatformSupport.supports(Platform.operatingSystem)) {
      throw UnsupportedError(
        'Path normalization is not supported on this platform: '
        '${Platform.operatingSystem}',
      );
    }
    return NativeFFmpeg.convertToFilePath(filePath);
  }

  static FFmpegInterface _createImplementation() {
    // FFmpegKit ships native FFmpeg/FFprobe implementations for all five
    // supported operating systems. No desktop ffmpeg executable is needed.
    if (FfmpegKitPlatformSupport.supports(Platform.operatingSystem)) {
      return NativeFFmpeg();
    }
    throw UnsupportedError(
      'FFmpeg operations are not supported on this platform: '
      '${Platform.operatingSystem}',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getSubtitleTracks(String videoPath) {
    return _implementation.getSubtitleTracks(videoPath);
  }

  @override
  Future<String> extractSubtitle(
    String videoPath,
    String outputPath,
    int streamIndex,
  ) {
    return _implementation.extractSubtitle(videoPath, outputPath, streamIndex);
  }

  @override
  Future<String> extractSubtitleWithTrackInfo(
    String videoPath,
    String outputPath,
    int streamIndex,
    Map<String, dynamic> trackInfo,
  ) {
    return _implementation.extractSubtitleWithTrackInfo(
      videoPath,
      outputPath,
      streamIndex,
      trackInfo,
    );
  }

  @override
  Future<double?> getVideoFramerate(String videoPath) {
    return _implementation.getVideoFramerate(videoPath);
  }

  /// Extract base filename from video path, handling various path formats
  /// This method properly handles both forward slashes and backslashes
  /// and extracts only the filename without extension
  static String extractBaseFilename(String videoPath) {
    String fileName = videoPath;
    
    // Remove URI scheme if present
    if (fileName.startsWith('file://')) {
      fileName = fileName.substring(7);
    }
    
    // Handle both forward and back slashes by finding the last occurrence of either
    int lastSlashIndex = -1;
    for (int i = fileName.length - 1; i >= 0; i--) {
      if (fileName[i] == '/' || fileName[i] == '\\') {
        lastSlashIndex = i;
        break;
      }
    }
    
    // Extract filename after the last slash
    if (lastSlashIndex != -1) {
      fileName = fileName.substring(lastSlashIndex + 1);
    }
    
    // Remove file extension
    int lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      fileName = fileName.substring(0, lastDotIndex);
    }
    
    // Clean up any remaining invalid characters for filename
    fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    return fileName.isNotEmpty ? fileName : 'video';
  }
}
