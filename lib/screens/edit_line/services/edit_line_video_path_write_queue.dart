/// Serializes persisted video-location mutations for one Edit Line route.
///
/// A pending picker save must not commit after a later Unload, even if the
/// underlying preference store completes operations out of order.
class EditLineVideoPathWriteQueue {
  final Future<void> Function(String path) save;
  final Future<void> Function() clear;
  Future<void> _tail = Future<void>.value();

  EditLineVideoPathWriteQueue({required this.save, required this.clear});

  Future<void> savePath(String path) => _enqueue(() => save(path));
  Future<void> clearPath() => _enqueue(clear);

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    // One failed operation must not poison later updates.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
