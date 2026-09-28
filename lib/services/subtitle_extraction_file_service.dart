import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SubtitleExtractionPaths {
  final String outputDirectory;
  final String outputFileName;

  const SubtitleExtractionPaths({
    required this.outputDirectory,
    required this.outputFileName,
  });
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
}
