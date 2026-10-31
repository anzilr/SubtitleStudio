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
      } catch (_) {
        if (kDebugMode) {
          print('Could not access Android temp directory; using fallback');
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
      } catch (_) {
        if (kDebugMode) {
          print('Could not access iOS temp directory; using fallback');
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
      return SubtitleExtractionPaths(
        outputDirectory: tempDir.path,
        outputFileName: outputFileName,
      );
    } catch (_) {
      if (kDebugMode) {
        print('Could not access temp directory; using system temp');
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
          if (kDebugMode) print('Created extraction output directory');
        } catch (_) {
          if (kDebugMode) {
            print('Could not create extraction output directory');
          }
          throw Exception('Cannot create extraction directory');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testFileName = '$outputDirectory/test_write_$timestamp.tmp';

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
        if (kDebugMode) print('Created cache directory for SAF temp files');
      }
      return outputDirectory;
    } catch (_) {
      if (kDebugMode) {
        print('Could not create cache directory');
      }
      return '/tmp';
    }
  }

  /// Saves a completed desktop extraction without removing an existing SRT
  /// until its replacement has been copied and verified on the same volume.
  ///
  /// [copyFile] is injectable to regression-test failed copies safely.
  static Future<String> copyDesktopResult({
    required String tempOutputFile,
    required String outputFilePath,
    Future<File> Function(File source, String target)? copyFile,
  }) async {
    final normalizedOutputFilePath =
        FFmpegHelper.normalizePath(outputFilePath);
    final destinationFile = File(normalizedOutputFilePath);
    final tempFile = File(tempOutputFile);

    if (path.equals(
      path.absolute(tempFile.path),
      path.absolute(destinationFile.path),
    )) {
      throw StateError('Extraction source and destination must differ.');
    }
    if (!await tempFile.exists()) {
      throw Exception('Temporary extraction file not found');
    }

    final tempFileSize = await tempFile.length();
    if (tempFileSize == 0) {
      await tempFile.delete();
      throw Exception(
        'FFmpeg extraction produced an empty file. '
        'The subtitle track may be empty or corrupted.',
      );
    }

    // Stage in the destination directory so the final rename stays on its
    // filesystem. If copying fails, the previous destination is untouched.
    final stagingDirectory =
        await destinationFile.parent.createTemp('.subtitle-extraction-');
    final stagedFile = File(path.join(stagingDirectory.path, 'next.srt'));
    final backupFile = File(path.join(stagingDirectory.path, 'previous.srt'));
    var committed = false;

    try {
      if (copyFile == null) {
        await tempFile.copy(stagedFile.path);
      } else {
        await copyFile(tempFile, stagedFile.path);
      }
      if (!await stagedFile.exists() ||
          await stagedFile.length() != tempFileSize) {
        throw StateError('Extracted subtitle copy failed verification.');
      }

      if (await destinationFile.exists()) {
        await destinationFile.rename(backupFile.path);
      }
      try {
        await stagedFile.rename(destinationFile.path);
      } catch (_) {
        // Never remove the backup if restoration fails: it remains available
        // in the staging directory for recovery.
        if (await backupFile.exists()) {
          await backupFile.rename(destinationFile.path);
        }
        rethrow;
      }
      committed = true;
    } finally {
      // An unsuccessful rollback leaves previous.srt intact for recovery.
      if (committed || !await backupFile.exists()) {
        try {
          await stagingDirectory.delete(recursive: true);
        } catch (_) {
          if (kDebugMode) print('Could not clean up extraction staging files');
        }
      }
    }

    await tempFile.delete();
    if (kDebugMode) print('Copied extracted file to final location (verified)');
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
      if (kDebugMode) print('iOS: Reading temporary extraction file');
    } else if (Platform.isAndroid && useDirectSave) {
      fileToRead = File(tempOutputFile);
      if (kDebugMode) print('Android SAF: Reading temporary extraction file');
    } else {
      fileToRead = File(outputFilePath);
      if (kDebugMode) print('Desktop: Reading saved extraction file');
    }

    final fileExists = await fileToRead.exists();
    if (kDebugMode) print('Extracted subtitle file exists: $fileExists');

    if (!fileExists) {
      if (kDebugMode) {
        print('Extracted subtitle file is missing');
      }
      throw Exception('Extracted subtitle file not found');
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
        print('Cleaned up temporary extraction file');
      }
    } catch (_) {
      if (kDebugMode) {
        print('Warning: Could not clean up temporary extraction file');
      }
    }
  }

}
