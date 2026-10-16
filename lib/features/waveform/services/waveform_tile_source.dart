import 'dart:collection';
import 'dart:math' as math;

import 'package:subtitle_studio/features/waveform/models/waveform_sample.dart';

/// Bounded display tile in absolute *pixel* coordinates. The source keeps
/// signed min/max peaks, matching the current waveform renderer semantics.
class WaveformViewportTile {
  final int firstPixel;
  final int samplesPerPixel;
  final List<List<WaveformSample>> channels;

  WaveformViewportTile({
    required this.firstPixel,
    required this.samplesPerPixel,
    required List<List<WaveformSample>> channels,
  }) : channels = List.unmodifiable(
      channels.map((channel) => List<WaveformSample>.unmodifiable(channel)));

  int get pixelCount => channels.isEmpty ? 0 : channels.first.length;
}

/// On-demand waveform pixel buckets, bounded by maxTiles rather than full
/// audio duration * zoom levels. No Isar/FFmpeg dependency. This foundation
/// is intentionally separate from the existing eager ZoomLevel renderer
/// until Android/Windows visual and latency measurements are complete.
class WaveformTileSource {
  WaveformData _data;
  String _identity;
  final int tileWidth;
  final int maxTiles;
  final LinkedHashMap<String, WaveformViewportTile> _cache =
      LinkedHashMap<String, WaveformViewportTile>();
  int _computeCount = 0;

  WaveformTileSource({
    required WaveformData data,
    required String sourceIdentity,
    this.tileWidth = 256,
    this.maxTiles = 16,
  }) : _data = data, _identity = sourceIdentity {
    if (tileWidth < 1 || maxTiles < 1) {
      throw ArgumentError('Tile dimensions and cache capacity must be positive.');
    }
    _validate(data);
  }

  int get cachedTileCount => _cache.length;
  int get computedTileCount => _computeCount;
  String get sourceIdentity => _identity;

  /// Reuse the service while invalidating every tile when source/track changes.
  void replaceSource(WaveformData data, {required String sourceIdentity}) {
    _validate(data);
    if (!identical(_data, data) || _identity != sourceIdentity) {
      _data = data;
      _identity = sourceIdentity;
      _cache.clear();
    }
  }

  void clear() => _cache.clear();

  /// Request the visible range; no full-track zoom buffer is allocated.
  /// The max visible width protects accidental enormous UI requests.
  List<WaveformViewportTile> visibleTiles({
    required int firstPixel,
    required int visiblePixels,
    required int samplesPerPixel,
  }) {
    if (firstPixel < 0 || visiblePixels < 0 ||
        samplesPerPixel < 1 || visiblePixels > 8192) {
      throw RangeError('Invalid viewport or samples-per-pixel.');
    }
    if (visiblePixels == 0 || _data.totalSamples == 0) return const [];
    final totalPixels =
        (_data.totalSamples + samplesPerPixel - 1) ~/ samplesPerPixel;
    if (firstPixel >= totalPixels) return const [];
    final lastExclusive = math.min(firstPixel + visiblePixels, totalPixels);
    final firstTile = firstPixel ~/ tileWidth;
    final lastTile = (lastExclusive - 1) ~/ tileWidth;
    final tiles = <WaveformViewportTile>[];
    for (var tileIndex = firstTile; tileIndex <= lastTile; tileIndex++) {
      final key = '$samplesPerPixel:$tileIndex';
      final cached = _cache.remove(key);
      if (cached != null) {
        _cache[key] = cached; // Move to most recently used position.
        tiles.add(cached);
        continue;
      }
      final created = _compute(tileIndex, samplesPerPixel, totalPixels);
      _cache[key] = created;
      _computeCount++;
      if (_cache.length > maxTiles) {
        _cache.remove(_cache.keys.first);
      }
      tiles.add(created);
    }
    return List<WaveformViewportTile>.unmodifiable(tiles);
  }

  WaveformViewportTile _compute(
      int tileIndex, int samplesPerPixel, int totalPixels) {
    final pixelStart = tileIndex * tileWidth;
    final count = math.min(tileWidth, totalPixels - pixelStart);
    const divisor = 1 / 32768.0;
    final channels = <List<WaveformSample>>[];
    for (var channel = 0; channel < _data.channels; channel++) {
      final pcm = _data.rawSamples[channel];
      final samples = <WaveformSample>[];
      for (var localPixel = 0; localPixel < count; localPixel++) {
        final first = (pixelStart + localPixel) * samplesPerPixel;
        final end = math.min(first + samplesPerPixel, _data.totalSamples);
        var low = 32767;
        var high = -32768;
        for (var sampleIndex = first; sampleIndex < end; sampleIndex++) {
          final sample = pcm[sampleIndex];
          if (sample < low) low = sample;
          if (sample > high) high = sample;
        }
        // Mirror the existing square-root scaling, including the sign.
        final negative = low * divisor;
        final positive = high * divisor;
        samples.add(WaveformSample(
          negative < 0 ? -math.sqrt(-negative) : math.sqrt(negative),
          positive < 0 ? -math.sqrt(-positive) : math.sqrt(positive),
        ));
      }
      channels.add(samples);
    }
    return WaveformViewportTile(
      firstPixel: pixelStart, samplesPerPixel: samplesPerPixel,
      channels: channels,
    );
  }

  static void _validate(WaveformData data) {
    if (data.channels < 1 || data.sampleRate < 1 ||
        data.totalSamples < 0 ||
        data.rawSamples.length != data.channels ||
        data.rawSamples.any((channel) =>
            channel.length < data.totalSamples)) {
      throw ArgumentError('Inconsistent waveform PCM metadata.');
    }
  }
}
