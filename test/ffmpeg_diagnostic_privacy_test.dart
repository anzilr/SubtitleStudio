import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/ffmpeg_helper.dart';
import 'package:subtitle_studio/services/subtitle_extraction_file_service.dart';

void main() {
  test('filename extraction does not print private media identities', () {
    final traces = <String>[];
    final fileName = runZoned(
      () => FFmpegHelper.extractBaseFilename(
        '/private/media_secret_marker/holiday_secret_marker.mkv',
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) => traces.add(message),
      ),
    );

    // Names continue to be used for output naming, just not diagnostics.
    expect(fileName, 'holiday_secret_marker');
    expect(traces.join('\n'), isNot(contains('secret_marker')));
  });

  test('unavailable desktop media does not escape through errors or prints',
      () async {
    final root = await Directory.systemTemp.createTemp('ffmpeg_secret_marker_');
    try {
      final missing = '${root.path}/missing_secret_marker.mkv';
      final traces = <String>[];
      final result = await runZoned<Future<String>>(
        () async {
          try {
            await SystemFFmpeg().getSubtitleTracks(missing);
          } catch (error) {
            return error.toString();
          }
          fail('An unavailable input must not produce subtitle tracks');
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) => traces.add(message),
        ),
      );
      expect(result, isNot(contains(root.path)));
      expect(result, isNot(contains('secret_marker')));
      expect(traces.join('\n'), isNot(contains(root.path)));
      expect(traces.join('\n'), isNot(contains('secret_marker')));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('failed desktop extraction copy preserves existing SRT', () async {
    final root = await Directory.systemTemp.createTemp('srt_copy_');
    try {
      final existing = File('${root.path}/existing.srt');
      final extracted = File('${root.path}/extracted.srt');
      await existing.writeAsString('previous subtitle');
      await extracted.writeAsString('replacement subtitle');

      await expectLater(
        SubtitleExtractionFileService.copyDesktopResult(
          tempOutputFile: extracted.path,
          outputFilePath: existing.path,
          copyFile: (_, __) async =>
              throw const FileSystemException('Simulated copy failure'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await existing.readAsString(), 'previous subtitle');
      expect(await extracted.readAsString(), 'replacement subtitle');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('short staged extraction copy cannot overwrite a valid SRT', () async {
    final root = await Directory.systemTemp.createTemp('srt_copy_');
    try {
      final existing = File('${root.path}/existing.srt');
      final extracted = File('${root.path}/extracted.srt');
      await existing.writeAsString('previous subtitle');
      await extracted.writeAsString('replacement subtitle');

      await expectLater(
        SubtitleExtractionFileService.copyDesktopResult(
          tempOutputFile: extracted.path,
          outputFilePath: existing.path,
          copyFile: (_, target) => File(target).writeAsString('short'),
        ),
        throwsStateError,
      );
      expect(await existing.readAsString(), 'previous subtitle');
      expect(await extracted.readAsString(), 'replacement subtitle');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('successful desktop extraction replaces SRT after staging', () async {
    final root = await Directory.systemTemp.createTemp('srt_copy_');
    try {
      final existing = File('${root.path}/existing.srt');
      final extracted = File('${root.path}/extracted.srt');
      await existing.writeAsString('previous subtitle');
      await extracted.writeAsString('replacement subtitle');

      final result = await SubtitleExtractionFileService.copyDesktopResult(
        tempOutputFile: extracted.path,
        outputFilePath: existing.path,
      );
      expect(File(result).readAsStringSync(), 'replacement subtitle');
      expect(await extracted.exists(), isFalse);
      expect(
        await root.list().where(
          (entity) => entity.path.contains('.subtitle-extraction-'),
        ).toList(),
        isEmpty,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('FFmpeg helper never surfaces raw command or process traces', () {
    final source = File('lib/utils/ffmpeg_helper.dart').readAsStringSync();
    for (final unsafeTrace in <String>[
      'Executing FFmpeg command:',
      'FFmpeg command:',
      'FFmpeg stdout:',
      'FFmpeg stderr:',
      'Original video path:',
      'Extracted filename:',
      'Files in output directory',
      'Log output:',
      r'${result.stderr}',
      r'${result.stdout}',
      r'${logMessages.join',
      'session.getLogs()',
    ]) {
      expect(source, isNot(contains(unsafeTrace)), reason: unsafeTrace);
    }

    // These identities belong in the actual FFmpeg arguments and filenames,
    // never in log messages or thrown user-facing errors.
    final unsafeInterpolation = RegExp(
      r'''(?:print|logInfo|logError|throw Exception)\([^;]*\$(?:videoPath|outputPath|outputFile|ffmpegPath|convertedPath|normalizedVideoPath|normalizedOutputFile|trackInfo|e\b)''',
      dotAll: false,
    );
    expect(source, isNot(matches(unsafeInterpolation)));
  });
}
