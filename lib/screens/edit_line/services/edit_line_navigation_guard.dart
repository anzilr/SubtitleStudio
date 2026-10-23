/// Guards Edit Line's asynchronous navigation and post-load UI updates.
///
/// Relative and jump navigation are exclusive; otherwise a second press can
/// perform its save against a half-loaded cue. Direct refreshes also receive
/// generation tokens so slow earlier loads cannot win after newer requests.
/// This class has no BuildContext, Riverpod or media ownership.
class EditLineNavigationGuard {
  int _generation = 0;
  bool _closed = false;
  bool _busy = false;

  bool get isNavigating => _busy;

  int? beginLoad() {
    if (_closed) return null;
    return ++_generation;
  }

  bool isCurrent(int? generation) =>
      generation != null && !_closed && generation == _generation;

  Future<void> runExclusive(Future<void> Function() action) async {
    if (_closed || _busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _closed = true;
    ++_generation;
  }
}
