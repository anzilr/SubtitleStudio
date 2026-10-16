import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_mpv_audio_stream_resolver.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_ffmpeg_plan.dart';

typedef PropertyMap = Map<String, String>;

PropertyMap _fixture() => {
  'track-list/count': '5',
  'track-list/0/type': 'video',
  'track-list/1/type': 'audio',
  'track-list/1/id': '7',
  'track-list/1/ff-index': '2',
  'track-list/2/type': 'sub',
  'track-list/3/type': 'audio',
  'track-list/3/id': '12',
  'track-list/3/ff-index': '4',
  'track-list/4/type': 'video',
};

Future<String> _read(PropertyMap map, String property) async =>
    map[property] ?? 'N/A';

void main() {
  const resolver = WaveformMpvAudioStreamResolver();

  test('nonconsecutive mpv IDs resolve correct global stream index', () async {
    final props = _fixture();
    final seven = await resolver.resolve(
      selectedMpvId: '7', getProperty: (key) => _read(props, key));
    final twelve = await resolver.resolve(
      selectedMpvId: '12', getProperty: (key) => _read(props, key));
    expect(seven, 'ffmpeg:stream:2');
    expect(twelve, 'ffmpeg:stream:4');
    expect(WaveformFfmpegPlan.streamMap(seven), '0:2');
    expect(WaveformFfmpegPlan.streamMap(twelve), '0:4');
    expect(WaveformFfmpegPlan(inputPath: 'v.mkv', outputPath: 'p.raw',
      selectedTrackId: twelve).arguments(), containsAllInOrder(['-map', '0:4']));
  });

  test('interleaved video streams never become audio-only ordinals',
      () async {
    final props = _fixture();
    props['track-list/3/id'] = '3';
    props['track-list/3/ff-index'] = '4';
    final id = await resolver.resolve(
        selectedMpvId: '3', getProperty: (key) => _read(props, key));
    expect(id, 'ffmpeg:stream:4');
    expect(WaveformFfmpegPlan.streamMap('3'), '0:a:2');
    expect(WaveformFfmpegPlan.streamMap(id), '0:4');
  });

  test('missing ff-index never invents a stream mapping', () async {
    final props = _fixture()..remove('track-list/3/ff-index');
    await expectLater(resolver.resolve(
      selectedMpvId: '12', getProperty: (key) => _read(props, key)),
      throwsFormatException);
  });

  test('missing or duplicate track IDs fail closed', () async {
    final props = _fixture();
    await expectLater(resolver.resolve(
        selectedMpvId: '99', getProperty: (key) => _read(props, key)),
        throwsStateError);
    props['track-list/1/id'] = '12';
    await expectLater(resolver.resolve(
        selectedMpvId: '12', getProperty: (key) => _read(props, key)),
        throwsStateError);
  });

  test('invalid mpv IDs and huge track counts are rejected', () async {
    for (final id in <String>['auto', 'no', '-1', '', ' 7', '7.0']) {
      await expectLater(resolver.resolve(
          selectedMpvId: id, getProperty: (key) => _read(_fixture(), key)),
          throwsFormatException);
    }
    for (final count in <String>['0', '-1', '257', 'NaN']) {
      final props = _fixture()..['track-list/count'] = count;
      await expectLater(resolver.resolve(
          selectedMpvId: '7', getProperty: (key) => _read(props, key)),
          throwsFormatException);
    }
  });

  test('invalid global stream selector never becomes default audio', () {
    for (final selector in <String>[
      'ffmpeg:stream:', 'ffmpeg:stream:-1', 'ffmpeg:stream:NaN',
      'ffmpeg:stream:100001', 'ffmpeg:stream:1.5',
    ]) {
      expect(() => WaveformFfmpegPlan.streamMap(selector),
          throwsFormatException, reason: selector);
    }
    expect(WaveformFfmpegPlan.streamMap('auto'), isNull);
    expect(WaveformFfmpegPlan.streamMap('ffmpeg:a:1'), '0:a:1');
  });

  test('property reader faults surface without legacy guess', () async {
    await expectLater(resolver.resolve(
      selectedMpvId: '7',
      getProperty: (key) async {
        if (key.endsWith('/ff-index')) {
          throw StateError('libmpv ff-index unavailable');
        }
        return _fixture()[key] ?? 'N/A';
      }), throwsStateError);
  });
}
