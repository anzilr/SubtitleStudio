import 'package:shared_preferences/shared_preferences.dart';

/// Desktop-only layout preferences. Deliberately separate from subtitles,
/// checkpoints and .msone serialization.
class StudioDockLayoutSnapshot {
  const StudioDockLayoutSnapshot({
    this.explorerWidth = 240,
    this.inspectorWidth = 320,
    this.videoShare = .43,
    this.waveformShare = .13,
    this.explorerOpen = true,
    this.inspectorOpen = true,
  });

  final double explorerWidth;
  final double inspectorWidth;
  final double videoShare;
  final double waveformShare;
  final bool explorerOpen;
  final bool inspectorOpen;
}

class StudioDockLayoutPreferences {
  static const String prefix = 'subtitle_studio.desktop.studio_dock.v1.';

  Future<StudioDockLayoutSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    double read(String key, double fallback, double min, double max) {
      final value = p.getDouble(prefix + key);
      return value == null || !value.isFinite
          ? fallback : value.clamp(min, max).toDouble();
    }
    return StudioDockLayoutSnapshot(
      explorerWidth: read('explorerWidth', 240, 200, 340),
      inspectorWidth: read('inspectorWidth', 320, 280, 440),
      videoShare: read('videoShare', .43, .24, .62),
      waveformShare: read('waveformShare', .13, .11, .26),
      explorerOpen: p.getBool(prefix + 'explorerOpen') ?? true,
      inspectorOpen: p.getBool(prefix + 'inspectorOpen') ?? true,
    );
  }

  Future<void> save(StudioDockLayoutSnapshot state) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(prefix + 'explorerWidth', state.explorerWidth);
    await p.setDouble(prefix + 'inspectorWidth', state.inspectorWidth);
    await p.setDouble(prefix + 'videoShare', state.videoShare);
    await p.setDouble(prefix + 'waveformShare', state.waveformShare);
    await p.setBool(prefix + 'explorerOpen', state.explorerOpen);
    await p.setBool(prefix + 'inspectorOpen', state.inspectorOpen);
  }
}
