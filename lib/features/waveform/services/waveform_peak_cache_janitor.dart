import 'dart:io';

/// Deletes *only* SubtitleStudio's expired compact peak caches and abandoned
/// partial writes. Does not touch raw PCM, external media, or recent cache files.
///
/// Cleanup is conservative: an in-progress write is never old enough to match
/// the two-hour partial cutoff under normal operation. Callers may additionally
/// protect the cache they are about to use.
class WaveformPeakCacheJanitor {
  const WaveformPeakCacheJanitor();

  static final RegExp _ownedFile = RegExp(
    r'^waveform_audio_[0-9]+_[0-9a-f]{8}\.pk1$');
  static final RegExp _partialFile = RegExp(
    r'^waveform_audio_[0-9]+_[0-9a-f]{8}\.pk1\.partial\.[0-9]+$');

  Future<int> clean(
    Directory directory, {
    Set<String> protectedPaths = const {},
    DateTime? now,
    Duration cacheLifetime = const Duration(days: 30),
    Duration partialLifetime = const Duration(hours: 2),
    int scanLimit = 4096,
  }) async {
    if (scanLimit < 1) throw ArgumentError.value(scanLimit, 'scanLimit');
    if (!await directory.exists()) return 0;
    final reference = now ?? DateTime.now();
    var deleted = 0;
    var scanned = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (++scanned > scanLimit) break;
      if (entry is! File || protectedPaths.contains(entry.path)) continue;
      final filename = entry.uri.pathSegments.last;
      final lifespan = _partialFile.hasMatch(filename)
          ? partialLifetime
          : _ownedFile.hasMatch(filename) ? cacheLifetime : null;
      if (lifespan == null) continue;
      try {
        final stat = await entry.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        if (reference.difference(stat.modified) < lifespan) continue;
        await entry.delete();
        deleted++;
      } on FileSystemException {
        // A file may have been deleted or replaced by another reader/writer.
      }
    }
    return deleted;
  }
}
