import 'dart:async';

/// Serializes operations that inspect, replace, or invalidate the *same*
/// waveform cache file. Different media sources can proceed independently.
///
/// Shared per Dart isolate so separate AudioProcessor instances cannot both
/// build/replace the same peak path concurrently. A waiting caller must still
/// validate its own request epoch when the critical section begins.
class WaveformCacheCoordinator {
  WaveformCacheCoordinator._();

  static final WaveformCacheCoordinator shared = WaveformCacheCoordinator._();

  final Map<String, Future<void>> _pending = <String, Future<void>>{};

  int get pendingKeys => _pending.length;

  Future<T> runExclusive<T>(
    String cachePath,
    Future<T> Function() operation,
  ) async {
    final predecessor = _pending[cachePath];
    final completed = Completer<void>();
    final tail = completed.future;
    _pending[cachePath] = tail;

    try {
      if (predecessor != null) await predecessor;
      return await operation();
    } finally {
      // Newer operations may already be queued on this same cache path.
      if (identical(_pending[cachePath], tail)) {
        _pending.remove(cachePath);
      }
      completed.complete();
    }
  }
}
