import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';

/// Versioned, bounded reduction of FFmpeg s16le 44.1-kHz mono PCM.
///
/// Each 16-input-sample frame stores signed mean/min/max in six bytes.
/// The mean is used for legacy visual parity; min/max are retained on disk
/// for a future peak-preserving renderer. No full 44.1-kHz PCM allocation.
class WaveformPeakCache {
  static const int inputRate = 44100;
  static const int frameSize = 16;
  static const int outputRate = inputRate >> 4;
  static const int bytesPerFrame = 6;
  static const int headerBytes = 28;
  static const int maxFrames = 60000000; // Hard cap against corrupt metadata.
  static const int _magic = 0x4B505753; // 'SWPK' in little-endian
  static const int _version = 1;
  static const int _reducedVersion = 2;

  const WaveformPeakCache._();

  static int _hash(int hash, int byte) =>
      ((hash ^ byte) * 0x01000193) & 0xffffffff;

  static Uint8List _header(int count, int checksum, {bool reduced = false}) {
    final data = ByteData(headerBytes);
    data.setUint32(0, _magic, Endian.little);
    data.setUint16(4, reduced ? _reducedVersion : _version, Endian.little);
    data.setUint16(6, reduced ? 1 : frameSize, Endian.little);
    data.setUint32(8, reduced ? outputRate : inputRate, Endian.little);
    data.setUint32(12, outputRate, Endian.little);
    data.setUint32(16, count, Endian.little);
    data.setUint32(20, checksum, Endian.little);
    data.setUint32(24, reduced ? 2 : bytesPerFrame, Endian.little);
    return data.buffer.asUint8List();
  }

  /// Creates a cache off to the side and promotes it only after the complete
  /// stream is flushed. A failed build never produces a valid cache header.
  static Future<WaveformData> build({
    required File pcmFile,
    required File cacheFile,
    bool Function()? isCancelled,
    bool inputAlreadyReduced = false,
  }) async {
    final bytes = await pcmFile.length();
    if (bytes.isOdd) {
      throw const FormatException('PCM contains a truncated 16-bit sample.');
    }
    final effectiveFrameSize = inputAlreadyReduced ? 1 : frameSize;
    final frames = bytes ~/ (effectiveFrameSize * 2);
    if (frames < 1 || frames > maxFrames) {
      throw const FormatException('PCM frame count outside safe bounds.');
    }
    await cacheFile.parent.create(recursive: true);
    final staging = File(cacheFile.path + '.partial.' +
        DateTime.now().microsecondsSinceEpoch.toString());
    final result = Int16List(frames);
    final writer = await staging.open(mode: FileMode.write);
    var checksum = 0x811c9dc5;
    var emitted = 0;
    var inputCount = 0;
    var sum = 0;
    var low = 32767;
    var high = -32768;
    int? pendingByte;
    // The previous implementation allocated a ByteData and Uint8List
    // for EVERY reduced sample. A long movie can have tens of millions of
    // samples, so write the same signed little-endian records into one
    // fixed-size chunk and reuse it across disk writes. Both V1 and V2
    // retain their existing byte layout and FNV checksum.
    final batch = Uint8List(24576); // multiple of V1(6) and V2(2)
    var batchUsed = 0;
    void emitInt16(int value) {
      final lowByte = value & 0xff;
      final highByte = (value >> 8) & 0xff;
      batch[batchUsed++] = lowByte;
      batch[batchUsed++] = highByte;
      checksum = _hash(_hash(checksum, lowByte), highByte);
    }

    try {
      await writer.writeFrom(_header(frames, 0, reduced: inputAlreadyReduced));
      await for (final chunk in pcmFile.openRead(0, frames * effectiveFrameSize * 2)) {
        if (isCancelled?.call() ?? false) {
          throw StateError('Waveform peak generation was cancelled.');
        }
        for (final byte in chunk) {
          if (pendingByte == null) {
            pendingByte = byte;
            continue;
          }
          var sample = pendingByte | (byte << 8);
          pendingByte = null;
          if (sample >= 0x8000) sample -= 0x10000;
          if (inputAlreadyReduced) {
            // V2 is already at the target rate; min/max and averaging
            // are unnecessary. Preserve every source sample exactly.
            result[emitted++] = sample;
            emitInt16(sample);
          } else {
            sum += sample;
            low = math.min(low, sample);
            high = math.max(high, sample);
            inputCount++;
            if (inputCount != frameSize) continue;

            final average = (sum / frameSize).round();
            result[emitted++] = average;
            emitInt16(average);
            emitInt16(low);
            emitInt16(high);
            inputCount = 0;
            sum = 0;
            low = 32767;
            high = -32768;
          }
          if (batchUsed >= batch.length) {
            await writer.writeFrom(batch, 0, batchUsed);
            batchUsed = 0;
          }
        }
      }
      if (isCancelled?.call() ?? false) {
        throw StateError('Waveform peak generation was cancelled.');
      }
      if (emitted != frames || inputCount != 0 || pendingByte != null) {
        throw const FormatException('Incomplete PCM reduction.');
      }
      if (batchUsed > 0) await writer.writeFrom(batch, 0, batchUsed);
      await writer.setPosition(0);
      await writer.writeFrom(_header(frames, checksum, reduced: inputAlreadyReduced));
      await writer.flush();
      await writer.close();
      if (isCancelled?.call() ?? false) {
        throw StateError('Waveform peak generation was cancelled.');
      }
      // Preserve an existing complete cache if promotion itself fails.
      await staging.rename(cacheFile.path);
      return _asWaveform(result);
    } catch (_) {
      await writer.close().catchError((Object _) {});
      if (await staging.exists()) await staging.delete();
      rethrow;
    }
  }

  /// Validates length before allocation and checksum before returning data.
  /// No corrupt partial cache ever becomes a usable waveform.
  static Future<WaveformData> load(File file) async {
    final length = await file.length();
    if (length < headerBytes) {
      throw const FormatException('Waveform peak cache is truncated.');
    }
    final reader = await file.open();
    try {
      final headBytes = await reader.read(headerBytes);
      if (headBytes.length != headerBytes) {
        throw const FormatException('Incomplete peak cache header.');
      }
      final h = ByteData.sublistView(Uint8List.fromList(headBytes));
      final count = h.getUint32(16, Endian.little);
      final version = h.getUint16(4, Endian.little);
      final reduced = version == _reducedVersion;
      final recordBytes = reduced ? 2 : bytesPerFrame;
      if (h.getUint32(0, Endian.little) != _magic ||
          (version != _version && !reduced) ||
          h.getUint16(6, Endian.little) != (reduced ? 1 : frameSize) ||
          h.getUint32(8, Endian.little) != (reduced ? outputRate : inputRate) ||
          h.getUint32(12, Endian.little) != outputRate ||
          h.getUint32(24, Endian.little) != recordBytes ||
          count < 1 || count > maxFrames ||
          length != headerBytes + count * recordBytes) {
        throw const FormatException('Invalid peak cache header or length.');
      }
      final stored = h.getUint32(20, Endian.little);
      var checksum = 0x811c9dc5;
      final values = Int16List(count);
      var index = 0;
      while (index < count) {
        final countThisChunk = math.min(4096, count - index);
        final block = await reader.read(countThisChunk * recordBytes);
        if (block.length != countThisChunk * recordBytes) {
          throw const FormatException('Truncated peak cache payload.');
        }
        final bytes = Uint8List.fromList(block);
        for (final b in bytes) {
          checksum = _hash(checksum, b);
        }
        final data = ByteData.sublistView(bytes);
        for (var i = 0; i < countThisChunk; i++) {
          final offset = i * recordBytes;
          final mean = data.getInt16(offset, Endian.little);
          if (!reduced) {
            final low = data.getInt16(offset + 2, Endian.little);
            final high = data.getInt16(offset + 4, Endian.little);
            if (low > high || mean < low || mean > high) {
              throw const FormatException('Invalid peak cache amplitude.');
            }
          }
          values[index++] = mean;
        }
      }
      if (stored != checksum) {
        throw const FormatException('Peak cache checksum mismatch.');
      }
      return _asWaveform(values);
    } finally {
      await reader.close();
    }
  }

  static WaveformData _asWaveform(Int16List mono) => WaveformData(
    channels: 1,
    sampleRate: outputRate,
    totalSamples: mono.length,
    rawSamples: [mono],
  );
}
