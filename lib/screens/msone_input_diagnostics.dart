import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
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
  static int _pointerSerial = 0;
  static int _editorPointers = 0;
  static int _homePointers = 0;

  static bool get isWatching => kDebugMode && _watching;

  static void watchAfterReturn() {
    if (!kDebugMode) return;
    _watching = true;
    _remainingPointers = 24;
    _pointerSerial = 0;
    _editorPointers = 0;
    _homePointers = 0;
    debugPrint('MSone input: probe armed for 24 touches (hit-test trace on first 12)');
  }

  static void onRootPointer(PointerDownEvent event) {
    if (!isWatching || _remainingPointers <= 0) return;
    final serial = ++_pointerSerial;
    debugPrint('MSone input: ROOT #$serial down '
        'x=${event.position.dx.toStringAsFixed(1)} '
        'y=${event.position.dy.toStringAsFixed(1)} '
        'view=${event.viewId} '
        'editorEvents=$_editorPointers homeEvents=$_homePointers '
        'remaining=$_remainingPointers');
    if (serial <= 12) {
      // The root Listener is hit even when a sibling Navigator OverlayEntry
      // intercepts touches. Inspect the actual render hit-test path to find
      // the *specific* barrier rather than guessing which route left it.
      try {
        final hits = HitTestResult();
        RendererBinding.instance.hitTestInView(
          hits, event.position, event.viewId);
        final description = hits.path.take(24).map((entry) {
          final target = entry.target;
          if (target is RenderObject) {
            final creator = target.debugCreator;
            final widgetType = creator is DebugCreator
                ? creator.element.widget.runtimeType.toString()
                : creator?.runtimeType.toString() ?? '?';
            return '${target.runtimeType}[$widgetType]';
          }
          return target.runtimeType.toString();
        }).join(' > ');
        debugPrint('MSone input: HITTEST #$serial '
            'count=${hits.path.length} $description');
      } catch (error) {
        debugPrint('MSone input: HITTEST #$serial failed: $error');
      }
    }
    if (--_remainingPointers <= 0) {
      _watching = false;
      debugPrint('MSone input: probe complete, '
          'editorEvents=$_editorPointers homeEvents=$_homePointers');
    }
  }

  static void onEditorPointer(PointerDownEvent event) {
    if (!isWatching) return;
    _editorPointers++;
    debugPrint('MSone input: EDITOR pointer #$_editorPointers '
        'x=${event.position.dx.toStringAsFixed(1)} '
        'y=${event.position.dy.toStringAsFixed(1)}');
  }

  static void onHomePointer(PointerDownEvent event) {
    if (!isWatching) return;
    _homePointers++;
    debugPrint('MSone input: HOME pointer #$_homePointers '
        'x=${event.position.dx.toStringAsFixed(1)} '
        'y=${event.position.dy.toStringAsFixed(1)}');
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
