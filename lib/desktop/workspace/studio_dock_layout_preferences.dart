import 'package:shared_preferences/shared_preferences.dart';
import 'studio_dock_geometry.dart';

/// Desktop-only layout preferences. Deliberately separate from subtitles,
/// checkpoints and .msone serialization.
class StudioDockLayoutSnapshot {
  const StudioDockLayoutSnapshot({
    this.explorerWidth = 240,
    this.inspectorWidth = 320,
    this.videoShare = StudioDockBands.defaultVideoShare,
    this.waveformShare = StudioDockBands.defaultWaveformShare,
    this.explorerOpen = true,
    this.inspectorOpen = true,
    this.videoOpen = false,
    this.waveformOpen = false,
    this.collapseEffects = true,
  });

  final double explorerWidth;
  final double inspectorWidth;
  final double videoShare;
  final double waveformShare;
  final bool explorerOpen;
  final bool inspectorOpen;
  /// Media panels reopen only when explicitly enabled and a source exists.
  final bool videoOpen;
  final bool waveformOpen;
  /// Visual-only effect folding; does not change or merge persisted cues.
  final bool collapseEffects;
}

class StudioDockLayoutPreferences {
  static const String prefix = 'subtitle_studio.desktop.studio_dock.v1.';
  static const int _verticalPresetVersion = 3;

  /// Reset only Studio Dock layout keys. Other shared preferences can contain
  /// document grants, quality profiles, or unrelated application state.
  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().where((key) => key.startsWith(prefix))) {
      await preferences.remove(key);
    }
  }

  Future<StudioDockLayoutSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    double read(String key, double fallback, double min, double max) {
      final value = p.getDouble(prefix + key);
      return value == null || !value.isFinite
          ? fallback : value.clamp(min, max).toDouble();
    }
    final legacyVideo = read('videoShare',
        StudioDockBands.defaultVideoShare, .18, .62);
    final legacyWaveform = read('waveformShare',
        StudioDockBands.defaultWaveformShare, .12, .38);
    // Upgrade prior default presets, not user-resized proportions. Preserve
    // existing panel widths, open states and manually chosen splits.
    final oldDefault = (legacyVideo - .38).abs() < .0001 &&
        (legacyWaveform - .24).abs() < .0001;
    final previousDefault = (legacyVideo - .26).abs() < .0001 &&
        (legacyWaveform - .17).abs() < .0001;
    final migrate = (p.getInt(prefix + 'verticalPresetVersion') ?? 1) <
        _verticalPresetVersion && (oldDefault || previousDefault);
    return StudioDockLayoutSnapshot(
      explorerWidth: read('explorerWidth', 240, 200, 340),
      inspectorWidth: read('inspectorWidth', 320, 280, 440),
      videoShare: migrate ? StudioDockBands.defaultVideoShare : legacyVideo,
      waveformShare: migrate ? StudioDockBands.defaultWaveformShare
          : legacyWaveform,
      explorerOpen: p.getBool(prefix + 'explorerOpen') ?? true,
      inspectorOpen: p.getBool(prefix + 'inspectorOpen') ?? true,
      videoOpen: p.getBool(prefix + 'videoOpen') ?? false,
      waveformOpen: p.getBool(prefix + 'waveformOpen') ?? false,
      collapseEffects: p.getBool(prefix + 'collapseEffects') ?? true,
    );
  }

  Future<void> save(StudioDockLayoutSnapshot state) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(prefix + 'explorerWidth', state.explorerWidth);
    await p.setDouble(prefix + 'inspectorWidth', state.inspectorWidth);
    await p.setDouble(prefix + 'videoShare', state.videoShare);
    await p.setDouble(prefix + 'waveformShare', state.waveformShare);
    await p.setInt(prefix + 'verticalPresetVersion', _verticalPresetVersion);
    await p.setBool(prefix + 'explorerOpen', state.explorerOpen);
    await p.setBool(prefix + 'inspectorOpen', state.inspectorOpen);
    await p.setBool(prefix + 'videoOpen', state.videoOpen);
    await p.setBool(prefix + 'waveformOpen', state.waveformOpen);
    await p.setBool(prefix + 'collapseEffects', state.collapseEffects);
  }
}
