import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Debug-only evidence across *both* Editor and Home after MSone Back.
///
/// This Listener sits above the Navigator and still sees pointer-downs
/// hit-tested to a nested modal barrier, when the editor Listener cannot.
/// Disabling after a bounded number of taps avoids permanent log spam.
class MsoneInputDiagnostics {
  MsoneInputDiagnostics._();

  static bool _watching = false;
  static int _remainingPointers = 0;

  static bool get isWatching => kDebugMode && _watching;

  static void watchAfterReturn() {
    if (!kDebugMode) return;
    _watching = true;
    _remainingPointers = 12;
    debugPrint('MSone input: root pointer probe armed for 12 touches');
  }

  static void onRootPointer(PointerDownEvent event) {
    if (!isWatching || _remainingPointers <= 0) return;
    debugPrint('MSone input: ROOT pointer-down '
        'x=${event.position.dx.toStringAsFixed(1)} '
        'y=${event.position.dy.toStringAsFixed(1)} '
        'remaining=$_remainingPointers');
    if (--_remainingPointers <= 0) _watching = false;
  }
}

class MsoneDebugNavigatorObserver extends NavigatorObserver {
  void _log(String action, Route<dynamic> route, Route<dynamic>? other) {
    if (!MsoneInputDiagnostics.isWatching) return;
    debugPrint('MSone nav: $action ${route.runtimeType} '
        'previous/next=${other.runtimeType} '
        'isCurrent=${route.isCurrent} '
        'overlays=${route.overlayEntries.length}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('pop', route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('remove', route, previousRoute);
  }
}
