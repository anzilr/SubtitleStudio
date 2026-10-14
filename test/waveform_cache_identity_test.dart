import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_cache_identity.dart';

void main() {
  test('source revision and selected audio track produce different cache keys',
      () async {
    final temp = await Directory.systemTemp.createTemp('waveform_identity_');
    addTearDown(() => temp.delete(recursive: true));
    final source = File(temp.path + Platform.pathSeparator + 'audio.wav');
    await source.writeAsBytes([1, 2, 3]);
    Future<String> key(String track) => WaveformCacheIdentity.pcmPath(
      temporaryDirectory: temp.path, subtitleCollectionId: 7,
      sourcePath: source.path, audioTrackId: track);
    final original = await key('1');
    expect(await key('1'), original);
    expect(await key('2'), isNot(original));
    await source.writeAsBytes([1, 2, 3, 4, 5, 6]);
    expect(await key('1'), isNot(original));
    expect(original, contains('waveform_audio_7_'));
  });

  test('reject mismatched metadata or truncated PCM', () {
    bool okay(int length, {int channels = 1, int rate = 44100,
        String path = 'same'}) =>
      WaveformCacheIdentity.metadataValid(
        actualPath: path, expectedPath: 'same',
        byteLength: length, totalSamples: 3,
        channels: channels, sampleRate: rate);
    expect(okay(6), isTrue);
    expect(okay(5), isFalse);
    expect(okay(8), isFalse);
    expect(okay(6, channels: 2), isFalse);
    expect(okay(6, rate: 48000), isFalse);
    expect(okay(6, path: 'other'), isFalse);
  });

  test('content URI identity includes selected track', () async {
    Future<String> key(String track) => WaveformCacheIdentity.pcmPath(
      temporaryDirectory: Directory.systemTemp.path,
      subtitleCollectionId: 4, sourcePath: 'content://provider/audio',
      audioTrackId: track);
    expect(await key('en'), isNot(await key('fr')));
  });
}
