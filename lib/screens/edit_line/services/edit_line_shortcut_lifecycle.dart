/// Orders desktop shortcut registration with Edit Line route teardown.
///
/// A route may be closed while platform shortcut registration is in flight.
/// Waiting for that registration before releasing shortcuts prevents late
/// callbacks from being installed after the screen has been disposed.
class EditLineShortcutLifecycle {
  bool _closed = false;
  Future<void>? _registration;
  Future<void>? _closing;

  bool get isActive => !_closed;

  Future<void> activate({
    required Future<void> Function() prepare,
    required Future<void> Function() register,
  }) {
    if (_closed) return Future<void>.value();
    return _registration ??= _activate(prepare, register);
  }

  Future<void> _activate(
    Future<void> Function() prepare,
    Future<void> Function() register,
  ) async {
    await prepare();
    if (!_closed) await register();
  }

  Future<void> close(Future<void> Function() unregister) {
    final existing = _closing;
    if (existing != null) return existing;
    _closed = true;
    return _closing = _close(unregister);
  }

  Future<void> _close(Future<void> Function() unregister) async {
    try {
      await _registration;
    } catch (_) {
      // Cleanup remains necessary after partial registration failures.
    } finally {
      await unregister();
    }
  }
}
