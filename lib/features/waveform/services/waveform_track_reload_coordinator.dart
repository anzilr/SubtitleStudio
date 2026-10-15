/// Per-editor asynchronous sequencing for experimental track-aware loading.
///
/// Invalidation happens synchronously before resolving player metadata, so the
/// old track cannot remain displayed while the new selection is inspected.
/// Every later continuation rechecks the request identity. Older failures
/// are ignored, not allowed to replace a newer ready waveform.
class WaveformTrackReloadCoordinator {
  int _generation = 0;
  bool _disposed = false;

  int get generation => _generation;

  void cancel() => _generation++;

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<void> reload({
    required Future<String?> Function() resolveStream,
    required void Function() invalidate,
    required Future<void> Function(String selector) load,
    required void Function(Object error) fail,
    required bool Function() isCurrentSource,
  }) async {
    if (_disposed) return;
    final generation = ++_generation;
    bool current() => !_disposed && _generation == generation &&
        isCurrentSource();

    // Tear down prior decode *before* the first await: the player may now be
    // playing another track even when metadata lookup is slow or fails.
    invalidate();
    if (!current()) return;
    try {
      final resolved = await resolveStream();
      if (!current()) return;
      // Explicit automatic mode avoids waveform controller's saved-ID
      // fallback, which otherwise could silently select an old track.
      await load(resolved ?? 'auto');
    } catch (error) {
      if (current()) fail(error);
    }
  }
}
