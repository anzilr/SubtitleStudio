import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_ffmpeg_plan.dart';

void main() {
  group('waveform FFmpeg extraction plan', () {
    test('automatic track maps no stream and retains gap-aware PCM contract',
        () {
      const plan = WaveformFfmpegPlan(
        inputPath: 'clip.mkv', outputPath: 'clip.raw');
      final args = plan.arguments();
      expect(WaveformFfmpegPlan.audioOrdinal(null), isNull);
      expect(WaveformFfmpegPlan.audioOrdinal('auto'), isNull);
      expect(args.contains('-map'), isFalse);
      expect(args, containsAllInOrder([
        '-nostdin', '-hide_banner', '-nostats', '-loglevel', 'error',
        '-y', '-i', 'clip.mkv',
        '-af', 'aresample=async=1:first_pts=0',
        '-ac', '1', '-ar', '44100',
        '-f', 's16le', '-acodec', 'pcm_s16le', 'clip.raw',
      ]));
      expect(args.last, 'clip.raw');
      expect(() => args.add('unexpected'), throwsUnsupportedError);
    });

    test('legacy Media Kit track IDs preserve existing mapping explicitly',
        () {
      expect(WaveformFfmpegPlan.audioOrdinal('0'), 0);
      expect(WaveformFfmpegPlan.audioOrdinal('1'), 0);
      expect(WaveformFfmpegPlan.audioOrdinal('2'), 1);
      expect(WaveformFfmpegPlan.audioOrdinal('3'), 2);
      for (final id in ['0', '1', '2', '3']) {
        final plan = WaveformFfmpegPlan(
          inputPath: 'video.mkv',
          outputPath: 'audio.raw',
          selectedTrackId: id,
        );
        final arguments = plan.arguments();
        final index = arguments.indexOf('-map');
        expect(index, greaterThanOrEqualTo(0));
        expect(arguments[index + 1],
            '0:a:' + WaveformFfmpegPlan.audioOrdinal(id).toString());
      }
    });

    test('explicit FFmpeg ordinal bypasses Media Kit heuristic', () {
      expect(WaveformFfmpegPlan.audioOrdinal('ffmpeg:a:0'), 0);
      expect(WaveformFfmpegPlan.audioOrdinal('ffmpeg:a:2'), 2);
      const plan = WaveformFfmpegPlan(
        inputPath: 'video.mkv',
        outputPath: 'audio.raw',
        selectedTrackId: 'ffmpeg:a:2',
      );
      expect(plan.arguments(), contains('0:a:2'));
    });

    test('invalid and disabled stream selections never fall back', () {
      for (final value in <String>[
        '', 'no', '-1', 'xyz', 'auto ', ' 1', 'ffmpeg:a:-1',
        'ffmpeg:a:NaN', 'ffmpeg:a:', 'ffmpeg:v:0',
        '100001',
      ]) {
        expect(() => WaveformFfmpegPlan.audioOrdinal(value),
            throwsFormatException, reason: 'selectedTrackId=' + value);
      }
      expect(() => const WaveformFfmpegPlan(
        inputPath: 'v.mkv', outputPath: 'x.raw',
        selectedTrackId: 'disabled',
      ).arguments(), throwsFormatException);
    });

    test('native string quoting protects file paths without altering argv',
        () {
      const plan = WaveformFfmpegPlan(
        inputPath: '/storage/emulated/0/A "B" clip.mkv',
        outputPath: '/cache/an audio file.raw',
        selectedTrackId: 'ffmpeg:a:1',
      );
      final args = plan.arguments();
      expect(args[args.indexOf('-i') + 1],
          '/storage/emulated/0/A "B" clip.mkv');
      expect(args.last, '/cache/an audio file.raw');
      final command = plan.ffmpegKitCommand();
      expect(command, contains(r'"/storage/emulated/0/A \"B\" clip.mkv"'));
      expect(command, contains('"/cache/an audio file.raw"'));
      expect(command, contains('-map 0:a:1'));
      expect(command, contains('-af aresample=async=1:first_pts=0'));
    });

    test('reject empty or control-character file paths', () {
      for (final path in <String>['', 'a\nb', 'a\rb', 'a\u0000b']) {
        expect(() => WaveformFfmpegPlan(
          inputPath: path, outputPath: 'audio.raw',
        ).arguments(), throwsFormatException);
        expect(() => WaveformFfmpegPlan(
          inputPath: 'video.mkv', outputPath: path,
        ).arguments(), throwsFormatException);
      }
    });

    test('resolved global FFmpeg streams are distinct from audio ordinal maps', () {
      expect(WaveformFfmpegPlan.streamMap('ffmpeg:stream:0'), '0:0');
      expect(WaveformFfmpegPlan.streamMap('ffmpeg:stream:4'), '0:4');
      const plan = WaveformFfmpegPlan(
        inputPath: 'video.mkv', outputPath: 'audio.raw',
        selectedTrackId: 'ffmpeg:stream:4',
      );
      expect(plan.arguments(), containsAllInOrder(['-map', '0:4']));
      expect(plan.ffmpegKitCommand(), contains('-map 0:4'));
      expect(plan.selectedStreamMap, '0:4');
      expect(const WaveformFfmpegPlan(
        inputPath: 'video.mkv', outputPath: 'audio.raw',
      ).selectedStreamMap, 'auto');
      expect(const WaveformFfmpegPlan(
        inputPath: 'video.mkv', outputPath: 'audio.raw',
        selectedTrackId: 'ffmpeg:a:2',
      ).selectedStreamMap, '0:a:2');
    });

    test('desktop and FFmpegKit use the same ordered command arguments',
        () {
      const plan = WaveformFfmpegPlan(
        inputPath: 'sample.mkv',
        outputPath: '/tmp/sample.raw',
        selectedTrackId: 'ffmpeg:a:1',
      );
      expect(plan.ffmpegKitCommand(), plan.arguments().join(' '));
      expect(plan.arguments().where((arg) => arg == '-map').length, 1);
      expect(plan.arguments().where(
          (arg) => arg == 'aresample=async=1:first_pts=0').length, 1);
    });
  });
}
