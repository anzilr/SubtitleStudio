import 'dart:async';

/// Debounces layout preferences independently and preserves the last drag
/// value when the Editor route is disposed before a timer fires.
///
/// Writers are captured repository methods, so outstanding saves never need
/// to access a disposed widget, Riverpod ref or native media player.
class EditorResizePreferenceCoordinator {
  final Future<void> Function(double) saveDesktop;
  final Future<void> Function(double) saveMobile;
  final void Function(Object error, StackTrace stackTrace)? onSaveError;
  final Duration desktopDelay;
  final Duration mobileDelay;

  Timer? _desktopTimer;
  Timer? _mobileTimer;
  double? _pendingDesktop;
  double? _pendingMobile;
  Future<void> _desktopQueue = Future<void>.value();
  Future<void> _mobileQueue = Future<void>.value();
  bool _closed = false;

  EditorResizePreferenceCoordinator({
    required this.saveDesktop,
    required this.saveMobile,
    this.onSaveError,
    this.desktopDelay = const Duration(milliseconds: 300),
    this.mobileDelay = const Duration(milliseconds: 500),
  });

  void scheduleDesktop(double ratio) {
    if (_closed) return;
    _pendingDesktop = ratio;
    _desktopTimer?.cancel();
    _desktopTimer = Timer(desktopDelay, _commitDesktop);
  }

  void scheduleMobile(double ratio) {
    if (_closed) return;
    _pendingMobile = ratio;
    _mobileTimer?.cancel();
    _mobileTimer = Timer(mobileDelay, _commitMobile);
  }

  void _commitDesktop() {
    _desktopTimer?.cancel();
    _desktopTimer = null;
    final ratio = _pendingDesktop;
    _pendingDesktop = null;
    if (ratio == null) return;
    _desktopQueue = _desktopQueue.then((_) => _write(saveDesktop, ratio));
  }

  void _commitMobile() {
    _mobileTimer?.cancel();
    _mobileTimer = null;
    final ratio = _pendingMobile;
    _pendingMobile = null;
    if (ratio == null) return;
    _mobileQueue = _mobileQueue.then((_) => _write(saveMobile, ratio));
  }

  Future<void> _write(Future<void> Function(double) writer, double ratio) async {
    try {
      await writer(ratio);
    } catch (error, stackTrace) {
      onSaveError?.call(error, stackTrace);
    }
  }

  /// Save queued values immediately and wait for already-running writes.
  /// Safe to invoke repeatedly. The caller may fire-and-forget on route exit.
  Future<void> flushAndDispose() {
    if (!_closed) {
      _closed = true;
      _commitDesktop();
      _commitMobile();
    }
    return Future.wait([_desktopQueue, _mobileQueue]);
  }
}
