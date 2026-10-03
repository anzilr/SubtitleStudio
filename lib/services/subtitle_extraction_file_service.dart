import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:subtitle_studio/utils/ffmpeg_helper.dart';

class SubtitleExtractionPaths {
  final String outputDirectory;
  final String outputFileName;

  const SubtitleExtractionPaths({
    required this.outputDirectory,
    required this.outputFileName,
  });

}

class SubtitleExtractionVerification {
  final String normalizedOutputPath;
  final bool exists;
  final int fileSize;
  final int attempts;
  final bool skipped;

  const SubtitleExtractionVerification({
    required this.normalizedOutputPath,
    required this.exists,
    required this.fileSize,
    required this.attempts,
    required this.skipped,
  });

  bool get isValid => skipped || (exists && fileSize > 0);
}

class SubtitleExtractionFileService {
  const SubtitleExtractionFileService._();

  static Future<SubtitleExtractionPaths> resolveExtractionPaths({
    required String outputFilePath,
    required bool useDirectSave,
  }) async {
    if (useDirectSave && Platform.isAndroid) {
      try {
        final tempDir = await getTemporaryDirectory();
        return SubtitleExtractionPaths(
          outputDirectory: tempDir.path,
          outputFileName: outputFilePath,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error getting temp directory, using fallback: $e');
        }
        return SubtitleExtractionPaths(
          outputDirectory: '/data/data/org.msone.subeditor/cache',
          outputFileName: outputFilePath,
        );
      }
    }

    final outputFileName = path.basename(outputFilePath);

    if (Platform.isIOS) {
      try {
        final tempDir = await getTemporaryDirectory();
        return SubtitleExtractionPaths(
          outputDirectory: tempDir.path,
          outputFileName: outputFileName,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error getting iOS temp directory, using fallback: $e');
        }
        final appDocsDir = await getApplicationDocumentsDirectory();
        return SubtitleExtractionPaths(
          outputDirectory: appDocsDir.path,
          outputFileName: outputFileName,
        );
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      if (kDebugMode) {
        print(
          'Using temp directory for desktop extraction: ${tempDir.path}',
        );
      }
      return SubtitleExtractionPaths(
        outputDirectory: tempDir.path,
        outputFileName: outputFileName,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting temp directory, using system temp: $e');
      }
      return SubtitleExtractionPaths(
        outputDirectory: Directory.systemTemp.path,
        outputFileName: outputFileName,
      );
    }
  }

  static Future<String> prepareOutputDirectory({
    required String outputDirectory,
    required bool useDirectSave,
  }) async {
    if (!useDirectSave || (!Platform.isAndroid && !Platform.isIOS)) {
      final outputDir = Directory(outputDirectory);
      final dirExists = await outputDir.exists();

      if (kDebugMode) {
        print('Directory exists: $dirExists');
      }

      if (!dirExists) {
        try {
          await outputDir.create(recursive: true);
          if (kDebugMode) {
            print('Created output directory: $outputDirectory');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error creating directory: $e');
          }
          throw Exception('Cannot create directory: $e');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testFileName = '$outputDirectory/test_write_$timestamp.tmp';

      if (kDebugMode) {
        print('Testing write permissions with file: $testFileName');
      }

      final testFile = File(testFileName);
      await testFile.writeAsString('test');

      final testFileExists = await testFile.exists();
      if (kDebugMode) {
        print('Test file created successfully: $testFileExists');
      }

      if (testFileExists) {
        await testFile.delete();
        if (kDebugMode) {
          print('Test file deleted');
        }
      }

      return outputDirectory;
    }

    try {
      final cacheDir = Directory(outputDirectory);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
        if (kDebugMode) {
          print(
            'Created cache directory for SAF temp files: $outputDirectory',
          );
        }
      }
      return outputDirectory;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating cache directory: $e');
      }
      return '/tmp';
    }
  }

  static Future<String> copyDesktopResult({
    required String tempOutputFile,
    required String outputFilePath,
  }) async {
    final normalizedOutputFilePath =
        FFmpegHelper.normalizePath(outputFilePath);
    final destinationFile = File(normalizedOutputFilePath);
    final tempFile = File(tempOutputFile);
    final normalizedTempPath = FFmpegHelper.normalizePath(tempOutputFile);

    if (kDebugMode) {
      print('Desktop extraction complete');
      print('Temp file path: $tempOutputFile');
      print('Normalized temp path: $normalizedTempPath');
      print('Final output path: $normalizedOutputFilePath');
    }

    if (!await tempFile.exists()) {
      throw Exception('Temp file not found: $tempOutputFile');
    }

    final tempFileSize = await tempFile.length();
    if (kDebugMode) {
      print('Temp file size: $tempFileSize bytes');
    }

    if (tempFileSize == 0) {
      await tempFile.delete();
      throw Exception(
        'FFmpeg extraction produced an empty file. '
        'The subtitle track may be empty or corrupted.',
      );
    }

    if (await destinationFile.exists()) {
      await destinationFile.delete();
      if (kDebugMode) {
        print('Deleted existing file at: $normalizedOutputFilePath');
      }
    }

    await tempFile.copy(normalizedOutputFilePath);
    if (kDebugMode) {
      print(
        'Copied file from temp to final location: '
        '$normalizedOutputFilePath',
      );
      print('Verifying copied file...');
    }

    final copiedFileSize = await destinationFile.length();
    if (kDebugMode) {
      print('Copied file size: $copiedFileSize bytes');
    }

    if (copiedFileSize != tempFileSize && kDebugMode) {
      print(
        'WARNING: File size mismatch! '
        'Temp: $tempFileSize, Copied: $copiedFileSize',
      );
    }

    await tempFile.delete();
    if (kDebugMode) {
      print('Cleaned up temp file: $tempOutputFile');
    }

    return normalizedOutputFilePath;
  }


  static Future<SubtitleExtractionVerification> verifyOutputFile({
    required String outputFilePath,
    int maxRetries = 10,
    Duration retryDelay = const Duration(milliseconds: 200),
  }) async {
    final normalizedOutputPath = FFmpegHelper.normalizePath(outputFilePath);

    if (Platform.isIOS) {
      if (kDebugMode) {
        print(
          'iOS: Skipping file verification - file picker handles saving',
        );
        print('Final output path: $normalizedOutputPath');
      }
      return SubtitleExtractionVerification(
        normalizedOutputPath: normalizedOutputPath,
        exists: true,
        fileSize: 0,
        attempts: 0,
        skipped: true,
      );
    }

    final extractedFile = File(normalizedOutputPath);
    var fileExists = false;
    var fileSize = 0;
    var attempts = 0;

    while (attempts < maxRetries) {
      fileExists = await extractedFile.exists();

      if (fileExists) {
        fileSize = await extractedFile.length();
        if (fileSize > 0) {
          attempts++;
          break;
        }

        if (attempts < maxRetries - 1) {
          if (kDebugMode) {
            print(
              'File exists but shows 0 bytes, retrying... '
              '(attempt ${attempts + 1}/$maxRetries)',
            );
          }
          await Future.delayed(retryDelay);
        }
      } else if (attempts < maxRetries - 1) {
        if (kDebugMode) {
          print(
            'File not found, retrying... '
            '(attempt ${attempts + 1}/$maxRetries)',
          );
        }
        await Future.delayed(retryDelay);
      }

      attempts++;
    }

    if (kDebugMode) {
      print('Original output path: $outputFilePath');
      print('Normalized output path: $normalizedOutputPath');
      print('File exists: $fileExists (after $attempts attempts)');
      if (fileExists) {
        print('File size: $fileSize bytes');
      }
    }

    return SubtitleExtractionVerification(
      normalizedOutputPath: normalizedOutputPath,
      exists: fileExists,
      fileSize: fileSize,
      attempts: attempts,
      skipped: false,
    );
  }


  static Future<String> readExtractedContent({
    required String tempOutputFile,
    required String outputFilePath,
    required bool useDirectSave,
  }) async {
    late final File fileToRead;

    if (Platform.isIOS) {
      fileToRead = File(tempOutputFile);
      if (kDebugMode) {
        print('iOS: Reading from temp file: $tempOutputFile');
      }
    } else if (Platform.isAndroid && useDirectSave) {
      fileToRead = File(tempOutputFile);
      if (kDebugMode) {
        print('Android SAF: Reading from temp file: $tempOutputFile');
      }
    } else {
      fileToRead = File(outputFilePath);
      if (kDebugMode) {
        print('Desktop: Reading from final destination: $outputFilePath');
      }
    }

    if (kDebugMode) {
      print('Attempting to read file: ${fileToRead.path}');
      print('File exists: ${await fileToRead.exists()}');
    }

    if (!await fileToRead.exists()) {
      if (kDebugMode) {
        print('File not found at: ${fileToRead.path}');
        print('Current working directory: ${Directory.current.path}');
      }
      throw Exception('Subtitle file not found: ${fileToRead.path}');
    }

    final content = await fileToRead.readAsString();
    if (kDebugMode) {
      print(
        'Successfully read SRT content: ${content.length} characters',
      );
    }
    return content;
  }


  static Future<void> cleanupTemporaryFile(
    String tempOutputFile, {
    String successMessage = 'Cleaned up temporary extraction file',
  }) async {
    try {
      final tempFile = File(tempOutputFile);
      if (!await tempFile.exists()) return;

      await tempFile.delete();
      if (kDebugMode) {
        print('$successMessage: $tempOutputFile');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Could not clean up temporary file: $e');
      }
    }
  }

}
