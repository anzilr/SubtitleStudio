import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_ffmpeg_plan.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_window_alignment.dart';

void main() {
  group('CP86 R9 windowed FFmpeg extraction contract', () {
    test('fast seek before input, accurate seek after, same stream and length',
        () {
      for (final mode in WaveformWindowSeekMode.values) {
        final plan = WaveformWindowFfmpegPlan(
          inputPath: '/storage/with a space/film.mkv',
          outputPath: '/tmp/preview.raw',
          selectedTrackId: 'ffmpeg:stream:4',
          start: const Duration(minutes: 30),
          duration: const Duration(seconds: 30),
          seekMode: mode,
        );
        final args = plan.arguments();
        final seekIndex = args.indexOf('-ss');
        final inputIndex = args.indexOf('-i');
        expect(seekIndex, mode == WaveformWindowSeekMode.inputFast
            ? lessThan(inputIndex) : greaterThan(inputIndex));
        expect(args, containsAllInOrder(['-map', '0:4']));
        expect(args, containsAllInOrder(['-af',
            'aresample=async=1:first_pts=0']));
        expect(args, containsAllInOrder(['-t', '30.000000']));
        expect(args, containsAll(['-vn', '-sn', '-dn']));
        expect(args, containsAllInOrder(['-ar', '2756']));
        expect(args.last, '/tmp/preview.raw');
        expect(args.where((s) => s == '-map'), hasLength(1));
        expect(args.where((s) => s == '-ss'), hasLength(1));
        expect(plan.maximumPcmBytes,
            greaterThan(30 * 2756 * 2));
        expect(plan.ffmpegKitCommand(), contains('"/storage/with a space/film.mkv"'));
        expect(() => args.add('extra'), throwsUnsupportedError);
      }
    });

    test('zero start omits seeking in both modes', () {
      for (final mode in WaveformWindowSeekMode.values) {
        final args = WaveformWindowFfmpegPlan(
          inputPath: 'video.mkv',
          outputPath: 'window.raw',
          start: Duration.zero,
          seekMode: mode,
        ).arguments();
        expect(args, isNot(contains('-ss')));
        expect(args, containsAllInOrder(['-t', '30.000000']));
      }
    });

    test('reject invalid duration/start, unsafe paths, and invalid tracks',
        () {
      final variants = <(Duration, Duration)>[
        (const Duration(seconds: -1), const Duration(seconds: 30)),
        (const Duration(hours: 25), const Duration(seconds: 30)),
        (Duration.zero, Duration.zero),
        (Duration.zero, const Duration(seconds: 61)),
      ];
      for (final (start, duration) in variants) {
        expect(() => WaveformWindowFfmpegPlan(
          inputPath: 'v.mkv', outputPath: 'a.raw',
          start: start, duration: duration,
        ).arguments(), throwsFormatException);
      }
      expect(() => const WaveformWindowFfmpegPlan(
        inputPath: 'a\nb.mkv', outputPath: 'c.raw',
        start: Duration.zero,
      ).arguments(), throwsFormatException);
      expect(() => const WaveformWindowFfmpegPlan(
        inputPath: 'v.mkv', outputPath: 'a.raw',
        start: Duration.zero, selectedTrackId: 'disabled',
      ).arguments(), throwsFormatException);
    });

    test('time arguments retain subsecond precision', () {
      final args = const WaveformWindowFfmpegPlan(
        inputPath: 'v.mkv', outputPath: 'a.raw',
        start: Duration(minutes: 1, milliseconds: 123),
        duration: Duration(seconds: 30, milliseconds: 500),
      ).arguments();
      expect(args, containsAllInOrder(['-ss', '60.123000']));
      expect(args, containsAllInOrder(['-t', '30.500000']));
    });
  });

  group('CP86 R9 diagnostic sample alignment', () {
    test('exact 2,756-Hz segment matches the full buffer', () {
      final all = Int16List.fromList(List.generate(18000,
          (i) => (i * 197 % 14000) - 7000));
      final clip = Int16List.fromList(all.sublist(2756, 2756 + 6000));
      final match = WaveformWindowAlignment.compare(
        window: clip, full: all, start: const Duration(seconds: 1));
      expect(match, isNotNull);
      expect(match!.normalizedError, 0);
      expect(match.inconclusiveSilence, isFalse);
    });

    test('silent or out-of-range source is not called aligned', () {
      final blank = Int16List(9000);
      final result = WaveformWindowAlignment.compare(
        window: blank, full: blank, start: Duration.zero);
      expect(result!.inconclusiveSilence, isTrue);
      expect(WaveformWindowAlignment.compare(
        window: blank, full: blank,
        start: const Duration(minutes: 99),
      ), isNull);
    });
  });
}
