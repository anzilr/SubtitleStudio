import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_ffmpeg_plan.dart';

Future<ProcessResult> _run(String executable, List<String> arguments) =>
    Process.run(executable, arguments).timeout(const Duration(seconds: 30));

void main() {
  test('FFmpeg stream indexes and timestamp gap match generated media',
      () async {
    try {
      final version = await _run('ffmpeg', ['-version']);
      if (version.exitCode != 0) return;
    } on ProcessException {
      // FFmpeg is optional. Pure-Dart resolver and plan tests remain active.
      return;
    }
    final dir = await Directory.systemTemp.createTemp(
        'subtitle_waveform_ffmpeg_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final media = dir.path + Platform.pathSeparator + 'fixture.mkv';
    final first = dir.path + Platform.pathSeparator + 'first.pcm';
    final delayed = dir.path + Platform.pathSeparator + 'delayed.pcm';
    final invalidPath = dir.path + Platform.pathSeparator + 'invalid.pcm';

    final generate = await _run('ffmpeg', [
      '-nostdin', '-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'lavfi', '-i', 'color=c=black:s=16x16:r=1:d=3',
      '-f', 'lavfi', '-i',
      'sine=frequency=440:sample_rate=44100:duration=2',
      '-itsoffset', '0.75', '-f', 'lavfi', '-i',
      'sine=frequency=880:sample_rate=44100:duration=2',
      '-map', '0:v:0', '-map', '1:a:0', '-map', '2:a:0',
      '-c:v', 'mpeg4', '-c:a', 'pcm_s16le', media,
    ]);
    expect(generate.exitCode, 0, reason: generate.stderr.toString());

    // ffprobe metadata includes one video and two interleaved audio streams.
    final probe = await _run('ffprobe', [
      '-v', 'error', '-show_entries', 'stream=index,codec_type,start_time',
      '-of', 'json', media,
    ]);
    expect(probe.exitCode, 0, reason: probe.stderr.toString());
    final payload = jsonDecode(probe.stdout as String) as Map<String, dynamic>;
    final streams = payload['streams'] as List<dynamic>;
    expect(streams.length, 3);
    expect((streams[0] as Map)['codec_type'], 'video');
    expect((streams[1] as Map)['codec_type'], 'audio');
    expect((streams[2] as Map)['codec_type'], 'audio');
    expect((streams[1] as Map)['index'], 1);
    expect((streams[2] as Map)['index'], 2);

    final firstPlan = WaveformFfmpegPlan(
      inputPath: media, outputPath: first,
      selectedTrackId: 'ffmpeg:stream:1',
    );
    final secondPlan = WaveformFfmpegPlan(
      inputPath: media, outputPath: delayed,
      selectedTrackId: 'ffmpeg:stream:2',
    );
    expect((await _run('ffmpeg', firstPlan.arguments())).exitCode, 0);
    expect((await _run('ffmpeg', secondPlan.arguments())).exitCode, 0);

    final a = await File(first).readAsBytes();
    final b = await File(delayed).readAsBytes();
    expect(a.length, 176400); // 2 sec * 44,100 samples * 2 bytes.
    expect(b.length, greaterThan(a.length));
    expect(b.take(4096).every((byte) => byte == 0), isTrue,
        reason: '750ms PTS gap should produce initial silent PCM.');
    expect(a.take(4096).any((byte) => byte != 0), isTrue,
        reason: '440Hz tone starts at zero without initial silence.');

    final invalid = await _run('ffmpeg', WaveformFfmpegPlan(
      inputPath: media, outputPath: invalidPath,
      selectedTrackId: 'ffmpeg:stream:9',
    ).arguments());
    expect(invalid.exitCode, isNot(0));
  });
}
