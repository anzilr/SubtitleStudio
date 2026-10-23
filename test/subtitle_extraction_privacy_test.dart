import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/services/subtitle_extraction_file_service.dart';

Future<(T, List<String>)> _capturePrints<T>(Future<T> Function() action) async {
  final output = <String>[];
  final result = await runZoned<Future<T>>(
    action,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => output.add(line),
    ),
  );
  return (result, output);
}

void main() {
  test('desktop extraction preserves saved bytes without logging file paths',
      () async {
    final root = await Directory.systemTemp.createTemp('private_media_marker_');
    try {
      final source = File('${root.path}/source_private_media_marker.srt');
      final destination = File('${root.path}/saved_private_media_marker.srt');
      const content = '1\n00:00:01,000 --> 00:00:02,000\nSubtitle text\n';
      await source.writeAsString(content);

      final (savedPath, copyOutput) = await _capturePrints(
        () => SubtitleExtractionFileService.copyDesktopResult(
          tempOutputFile: source.path,
          outputFilePath: destination.path,
        ),
      );
      expect(savedPath, destination.path);
      expect(await destination.readAsString(), content);
      expect(await source.exists(), isFalse);

      final (verification, verifyOutput) = await _capturePrints(
        () => SubtitleExtractionFileService.verifyOutputFile(
          outputFilePath: destination.path,
          retryDelay: Duration.zero,
        ),
      );
      expect(verification.isValid, isTrue);
      expect(verification.fileSize, content.length);

      final (readContent, readOutput) = await _capturePrints(
        () => SubtitleExtractionFileService.readExtractedContent(
          tempOutputFile: source.path,
          outputFilePath: destination.path,
          useDirectSave: false,
        ),
      );
      expect(readContent, content);

      final diagnostics = [...copyOutput, ...verifyOutput, ...readOutput]
          .join('\n');
      expect(diagnostics, contains('Copied extracted file'));
      expect(diagnostics, contains('File size:'));
      expect(diagnostics, isNot(contains(root.path)));
      expect(diagnostics, isNot(contains('private_media_marker')));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('missing extraction source fails without including its path', () async {
    final root = await Directory.systemTemp.createTemp('private_media_marker_');
    try {
      final missing = '${root.path}/missing_private_media_marker.srt';
      final (errorText, diagnostics) = await _capturePrints(() async {
        try {
          await SubtitleExtractionFileService.copyDesktopResult(
            tempOutputFile: missing,
            outputFilePath: '${root.path}/output.srt',
          );
        } catch (error) {
          return error.toString();
        }
        fail('Expected a missing temporary file error');
      });
      expect(errorText, contains('Temporary extraction file not found'));
      expect(errorText, isNot(contains(root.path)));
      expect(diagnostics.join('\n'), isNot(contains(root.path)));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('extraction screen does not contain previous path-bearing traces', () {
    final source = File('lib/widgets/subtitle_extract_options_sheet.dart')
        .readAsStringSync();
    for (final unsafeTrace in <String>[
      'Selected video path:',
      'Original filename:',
      r'Output directory: $',
      'Original SAF path:',
      'SAF URI:',
      'Original temp file path preserved:',
      'FFmpeg extracted to temp file:',
      r'Final output: $',
      'Updated originalFileUri to:',
    ]) {
      expect(source, isNot(contains(unsafeTrace)), reason: unsafeTrace);
    }
  });
}
