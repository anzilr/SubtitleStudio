import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

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
  static int _homeTraceCount = 0;

  static bool get isWatching => kDebugMode && _watching;

  static void watchAfterReturn() {
    if (!kDebugMode) return;
    _watching = true;
    _remainingPointers = 24;
    _pointerSerial = 0;
    _editorPointers = 0;
    _homePointers = 0;
    _homeTraceCount = 0;
    debugPrint('MSone input: probe armed for 24 touches (hit-test trace on first 12)');
    debugPrint('MSone input: ROUTES at return ${MsoneDebugNavigatorObserver.describeRoutes()}');
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
    // Trace three Home taps after the Editor pops. R11 missed this phase.
    final onHome = MsoneDebugNavigatorObserver.activeRouteCount == 1;
    final traceHome = onHome && _homeTraceCount++ < 3;
    if (serial <= 12 || traceHome) {
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
        // The render-object prefix reveals a barrier but not its owner.
        // Capture the widget ancestry and route stack without changing input.
        if (serial <= 3 || traceHome) {
          debugPrint('MSone input: HITTEST owner #$serial '
              '${_describeHitOwner(hits)}');
          debugPrint('MSone input: ROUTES #$serial '
              '${MsoneDebugNavigatorObserver.describeRoutes()}');
        }
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

  static String _describeHitOwner(HitTestResult result) {
    if (result.path.isEmpty) return '<empty hit-test path>';
    final target = result.path.first.target;
    if (target is! RenderObject) return target.runtimeType.toString();
    final creator = target.debugCreator;
    if (creator is! DebugCreator) return '${target.runtimeType} [no DebugCreator]';
    final widgets = <String>[creator.element.widget.runtimeType.toString()];
    creator.element.visitAncestorElements((ancestor) {
      widgets.add(ancestor.widget.runtimeType.toString());
      return widgets.length < 36;
    });
    return widgets.join(' < ');
  }

  // Distinguishes an intercepting hit-test target (DOWN+UP reached the
  // Navigator) from a device/engine stream that never completes the tap.
  static void onRootPointerUp(PointerUpEvent event) {
    if (!isWatching) return;
    debugPrint('MSone input: ROOT pointer-up '
        'pointer=${event.pointer} view=${event.viewId}');
  }

  static void onRootPointerCancel(PointerCancelEvent event) {
    if (!isWatching) return;
    debugPrint('MSone input: ROOT pointer-CANCEL '
        'pointer=${event.pointer} view=${event.viewId}');
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

/// Tracks routes before the post-MSone probe starts. This is debug-only
/// observation and does not mutate Navigator routes or remove overlays.
class MsoneDebugNavigatorObserver extends NavigatorObserver {
  static final List<Route<dynamic>> _activeRoutes = [];
  static int get activeRouteCount => _activeRoutes.length;
  static final List<Route<dynamic>> _recentPopped = [];

  static String _routeInfo(Route<dynamic> route) {
    final overlay = route.overlayEntries;
    final entries = overlay.asMap().entries.map((entry) =>
        '${entry.key}:${entry.value.mounted ? 'mounted' : 'unmounted'}'
        '/opaque=${entry.value.opaque}'
        '/keep=${entry.value.maintainState}').join(',');
    final modal = route is ModalRoute<dynamic> ? route : null;
    final transition = modal == null ? '' :
        ', anim=${modal.animation?.status}, secondary=${modal.secondaryAnimation?.status}'
        ', offstage=${modal.offstage}';
    return '${route.runtimeType}(name=${route.settings.name}, '
        'current=${route.isCurrent}, active=${route.isActive}$transition, '
        'entries=[$entries])';
  }

  static String describeRoutes() {
    final active = _activeRoutes.map(_routeInfo).join(' -> ');
    final popping = _recentPopped
        .where((route) => route.overlayEntries.any((entry) => entry.mounted))
        .map(_routeInfo)
        .join(' | ');
    final navigator = _activeRoutes.isNotEmpty
        ? _activeRoutes.last.navigator
        : null;
    return 'gestureInProgress=${navigator?.userGestureInProgress} '
        'active=[$active] poppedStillMounted=[$popping]';
  }

  void _log(String action, Route<dynamic> route, Route<dynamic>? other) {
    if (!MsoneInputDiagnostics.isWatching) return;
    debugPrint('MSone nav: $action ${route.runtimeType} '
        'previous/next=${other.runtimeType} '
        'isCurrent=${route.isCurrent} '
        'overlays=${route.overlayEntries.length} '
        'stack=${describeRoutes()}');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) {
      _activeRoutes.clear();
      _recentPopped.clear();
    }
    _activeRoutes.remove(route);
    _activeRoutes.add(route);
    _log('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _activeRoutes.remove(route);
    _recentPopped.add(route);
    if (_recentPopped.length > 8) _recentPopped.removeAt(0);
    _log('pop', route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _activeRoutes.remove(route);
    _log('remove', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = _activeRoutes.indexOf(oldRoute);
      if (index >= 0) {
        _activeRoutes.removeAt(index);
        if (newRoute != null) _activeRoutes.insert(index, newRoute);
      } else if (newRoute != null) {
        _activeRoutes.add(newRoute);
      }
    } else if (newRoute != null) {
      _activeRoutes.add(newRoute);
    }
    if (newRoute != null) _log('replace', newRoute, oldRoute);
  }
}

/// Passive page-route barrier labeling on debug builds. In release mode the
/// original MaterialPageRoute barrier is returned unchanged.
class MsoneDiagnosticPageRoute<T> extends MaterialPageRoute<T> {
  MsoneDiagnosticPageRoute({
    required super.builder,
    required this.debugBarrierName,
    super.settings,
  });

  final String debugBarrierName;

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    if (!kDebugMode) return barrier;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        if (!MsoneInputDiagnostics.isWatching) return;
        debugPrint('MSone barrier OWNER=$debugBarrierName '
            'pointer=${event.pointer} current=$isCurrent '
            'active=$isActive anim=${animation?.status}');
      },
      child: barrier,
    );
  }
}
