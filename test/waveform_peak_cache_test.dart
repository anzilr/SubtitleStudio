import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/features/waveform/services/waveform_peak_cache.dart';

Future<File> _writePcm(Directory directory, List<int> samples) async {
  final file = File(directory.path + Platform.pathSeparator + 'source.pcm');
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(i * 2, samples[i], Endian.little);
  }
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file;
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('subtitle_wave_pk_');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File cache() => File(
      directory.path + Platform.pathSeparator + 'waveform_test.pk1');

  test('streamed mean exactly matches legacy mono decimation including signs',
      () async {
    final samples = List<int>.generate(16003, (i) =>
        i % 97 == 0 ? -32768 : i % 107 == 0 ? 32767 :
        ((i * 337) % 62000) - 31000);
    final raw = await _writePcm(directory, samples);
    final data = await WaveformPeakCache.build(
        pcmFile: raw, cacheFile: cache());
    expect(data.channels, 1);
    expect(data.sampleRate, 44100 >> 4);
    expect(data.totalSamples, 1000);
    for (var i = 0; i < data.totalSamples; i++) {
      final begin = i * 16;
      final expected = (samples.skip(begin).take(16)
          .reduce((a, b) => a + b) / 16).round();
      expect(data.rawSamples[0][i], expected, reason: 'block $i');
    }
    final readback = await WaveformPeakCache.load(cache());
    expect(readback.rawSamples.single, data.rawSamples.single);
    // Cache is a small fixed-size peak format rather than full raw PCM.
    expect(await cache().length(),
        WaveformPeakCache.headerBytes +
        data.totalSamples * WaveformPeakCache.bytesPerFrame);
  });

  test('chunk boundaries preserve signed -32768 and +32767 extrema',
      () async {
    final samples = List<int>.generate(70000, (i) => i.isEven ? -32768 : 32767);
    final pcm = await _writePcm(directory, samples);
    final output = await WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache());
    expect(output.totalSamples, samples.length ~/ 16);
    expect(output.rawSamples.first.every((x) => x == -1), isTrue);
    final disk = await cache().readAsBytes();
    final record = ByteData.sublistView(disk);
    expect(record.getInt16(WaveformPeakCache.headerBytes, Endian.little), -1);
    expect(record.getInt16(WaveformPeakCache.headerBytes + 2, Endian.little),
        -32768);
    expect(record.getInt16(WaveformPeakCache.headerBytes + 4, Endian.little),
        32767);
  });

  test('truncated, corrupt and tampered cache is rejected', () async {
    final pcm = await _writePcm(directory, List<int>.filled(256, 231));
    await WaveformPeakCache.build(pcmFile: pcm, cacheFile: cache());
    final valid = await cache().readAsBytes();
    for (final index in [0, 4, 16, 20, 28]) {
      final changed = Uint8List.fromList(valid);
      changed[index] ^= 0xff;
      await cache().writeAsBytes(changed);
      await expectLater(WaveformPeakCache.load(cache()),
          throwsFormatException, reason: 'corruption offset $index');
    }
    await cache().writeAsBytes(valid.sublist(0, valid.length - 1));
    await expectLater(WaveformPeakCache.load(cache()),
        throwsFormatException);
    await cache().writeAsBytes([]);
    await expectLater(WaveformPeakCache.load(cache()),
        throwsFormatException);
  });

  test('forged cache length is rejected before allocation', () async {
    final pcm = await _writePcm(directory, List<int>.filled(32, 1));
    await WaveformPeakCache.build(pcmFile: pcm, cacheFile: cache());
    final bytes = await cache().readAsBytes();
    final header = ByteData.sublistView(bytes);
    header.setUint32(16, 0xffffffff, Endian.little);
    await cache().writeAsBytes(bytes);
    await expectLater(WaveformPeakCache.load(cache()),
        throwsFormatException);
  });

  test('odd byte count, empty PCM, and too-short frames never create cache',
      () async {
    final pcm = await _writePcm(directory, [1, 2, 3]);
    await expectLater(WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache()), throwsFormatException);
    expect(await cache().exists(), isFalse);
    await pcm.writeAsBytes([0x12]);
    await expectLater(WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache()), throwsFormatException);
    expect(await cache().exists(), isFalse);
    await pcm.writeAsBytes([]);
    await expectLater(WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache()), throwsFormatException);
    expect(await cache().exists(), isFalse);
  });

  test('variable amplitude aggregates without dropping complete frames',
      () async {
    final samples = <int>[];
    for (var frame = 0; frame < 4098; frame++) {
      samples.addAll(List<int>.generate(16,
          (j) => (math.sin(frame / 3) * 25000).round() - (j * 17)));
    }
    final pcm = await _writePcm(directory, samples);
    final built = await WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache());
    final loaded = await WaveformPeakCache.load(cache());
    expect(loaded.totalSamples, 4098);
    expect(loaded.rawSamples.single, built.rawSamples.single);
    expect(loaded.rawSamples.first[4097],
        (samples.skip(4097 * 16).take(16)
            .reduce((a, b) => a + b) / 16).round());
  });

  test('cancellation after streaming preserves previous cache and removes staging',
      () async {
    final pcm = await _writePcm(directory, List<int>.filled(512, 111));
    await WaveformPeakCache.build(pcmFile: pcm, cacheFile: cache());
    final original = await cache().readAsBytes();
    await pcm.writeAsBytes(List<int>.filled(1024, 0));
    var cancellationChecks = 0;
    await expectLater(
      WaveformPeakCache.build(
        pcmFile: pcm,
        cacheFile: cache(),
        isCancelled: () => ++cancellationChecks >= 2,
      ),
      throwsStateError,
    );
    expect(cancellationChecks, greaterThanOrEqualTo(2));
    expect(await cache().readAsBytes(), original);
    expect(directory.listSync().whereType<File>()
        .where((file) => file.path.contains('.partial.')), isEmpty);
  });

  test('no half-written destination after invalid source failure', () async {
    final pcm = await _writePcm(directory, List<int>.filled(256, 123));
    await WaveformPeakCache.build(pcmFile: pcm, cacheFile: cache());
    final correctBytes = await cache().readAsBytes();
    await pcm.writeAsBytes([0xab]); // extraction interrupted
    await expectLater(WaveformPeakCache.build(
        pcmFile: pcm, cacheFile: cache()), throwsFormatException);
    expect(await cache().readAsBytes(), correctBytes);
    expect(directory.listSync().whereType<File>()
        .where((f) => f.path.contains('.partial.')), isEmpty);
  });
}
