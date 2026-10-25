import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

import 'studio_dock_playback_link.dart';
import 'studio_dock_waveform_reload_guard.dart';

/// Waveform uses its own session-scoped Riverpod controller and the existing
/// waveform/seek coordinator, but NEVER creates a media_kit player.
class StudioDockWaveformSurface extends StatelessWidget {
  const StudioDockWaveformSurface({
    super.key,
    required this.videoPath,
    required this.collectionId,
    required this.subtitles,
    required this.playback,
    this.onApplyTimeEdit,
    this.onAddLineConfirmed,
    this.onSubtitleHighlight,
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyTimeEdit;
  final void Function(Duration start, Duration end)? onAddLineConfirmed;
  final ValueChanged<int>? onSubtitleHighlight;

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: _WaveformBody(
      videoPath: videoPath,
      collectionId: collectionId,
      subtitles: subtitles,
      playback: playback,
      onApplyTimeEdit: onApplyTimeEdit,
      onAddLineConfirmed: onAddLineConfirmed,
      onSubtitleHighlight: onSubtitleHighlight,
    ),
  );
}

class _WaveformBody extends ConsumerStatefulWidget {
  const _WaveformBody({
    required this.videoPath,
    required this.collectionId,
    required this.subtitles,
    required this.playback,
    this.onApplyTimeEdit,
    this.onAddLineConfirmed,
    this.onSubtitleHighlight,
  });

  final String videoPath;
  final int collectionId;
  final List<SubtitleLine> subtitles;
  final StudioDockPlaybackLink playback;
  final Future<bool> Function(int cueNumber, String start, String end)?
      onApplyTimeEdit;
  final void Function(Duration start, Duration end)? onAddLineConfirmed;
  final ValueChanged<int>? onSubtitleHighlight;

  @override
  ConsumerState<_WaveformBody> createState() => _WaveformBodyState();
}

class _WaveformBodyState extends ConsumerState<_WaveformBody> {
  int _loadRevision = 0;
  bool _waveformVisible = true;
  bool _regenerating = false;
  String? _commandError;

  @override
  void initState() {
    super.initState();
    widget.playback.audio.addListener(_scheduleLoad);
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant _WaveformBody old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.audio.removeListener(_scheduleLoad);
      widget.playback.audio.addListener(_scheduleLoad);
    }
    if (old.videoPath != widget.videoPath ||
        old.collectionId != widget.collectionId ||
        old.playback != widget.playback) {
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    _loadRevision++;
    widget.playback.audio.removeListener(_scheduleLoad);
    super.dispose();
  }

  void _scheduleLoad() {
    final revision = ++_loadRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _loadRevision) return;
      final selection = widget.playback.audio.value;
      final controller = ref.read(waveformControllerProvider.notifier);
      switch (selection.status) {
        case StudioDockAudioStatus.waiting:
          // Do not display a previous audio track during mpv track changes.
          unawaited(controller.dispatch(const ClearWaveform()));
        case StudioDockAudioStatus.unavailable:
          unawaited(controller.dispatch(WaveformTrackSelectionFailed(
            selection.error ?? 'Audio track metadata is unavailable.',
            filePath: widget.videoPath,
          )));
        case StudioDockAudioStatus.ready:
          // A player-resolved null selector means *auto*, not the older
          // saved FFmpeg preference for this subtitle collection.
          unawaited(controller.dispatch(LoadAudioFile(
            widget.videoPath,
            subtitleCollectionId: widget.collectionId,
            audioTrackId: selection.streamSelector,
            useSavedAudioTrackPreference: false,
          )));
      }
    });
  }

  Future<void> _regenerateWaveform() async {
    final selection = widget.playback.audio.value;
    if (_regenerating || selection.status != StudioDockAudioStatus.ready) return;
    final path = widget.videoPath;
    final collection = widget.collectionId;
    final request = StudioDockWaveformReloadSelection(
      playback: widget.playback,
      videoPath: path,
      collectionId: collection,
      trackId: selection.trackId,
      streamSelector: selection.streamSelector,
    );
    final revision = ++_loadRevision; // Invalidate a queued automatic load.
    bool isCurrent() =>
        mounted &&
        _loadRevision == revision &&
        request.matches(
          playback: widget.playback,
          videoPath: widget.videoPath,
          collectionId: widget.collectionId,
        );
    setState(() {
      _regenerating = true;
      _commandError = null;
      _waveformVisible = true;
    });
    try {
      // Match mobile cache invalidation and retain the selected audio stream.
      await StudioDockWaveformReloadGuard.run(
        isCurrent: isCurrent,
        clearCache: () => ref.read(waveformPreferencesRepositoryProvider)
            .clearWaveformCache(collection),
        clearWaveform: () => ref.read(waveformControllerProvider.notifier)
            .dispatch(const ClearWaveform()),
        loadWaveform: () => ref.read(waveformControllerProvider.notifier)
            .dispatch(LoadAudioFile(
              path,
              subtitleCollectionId: collection,
              audioTrackId: selection.streamSelector,
              useSavedAudioTrackPreference: false,
            )),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _commandError =
            'Could not regenerate waveform. Check the audio track and retry.');
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waveform = ref.watch(waveformControllerProvider);
    final controlsInMainHeader = _waveformVisible && waveform is WaveformReady;
    Widget toolbar({Widget? controls, Duration? position}) =>
        ValueListenableBuilder<StudioDockAudioSource>(
          valueListenable: widget.playback.audio,
          builder: (context, source, _) => StudioDockWaveformToolbar(
            visible: _waveformVisible,
            canRegenerate: source.status == StudioDockAudioStatus.ready,
            busy: _regenerating,
            compactControls: controls,
            position: position,
            onToggleVisibility: () => setState(() {
              _waveformVisible = !_waveformVisible;
              _commandError = null;
            }),
            onRegenerate: () => unawaited(_regenerateWaveform()),
          ),
        );
    return Column(children: [
      // When ready, the shared waveform actions are composed into this very
      // same header. A separate fallback header is only for loading/hidden.
      if (!controlsInMainHeader)
        SizedBox(height: 32, child: toolbar()),
      if (_commandError != null)
        Text(_commandError!, key: const ValueKey('studio-waveform-command-error'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_waveformVisible)
        Expanded(
          child: ValueListenableBuilder<Duration>(
            valueListenable: widget.playback.position,
            builder: (context, position, _) => ClipRect(
              child: LayoutBuilder(builder: (context, size) => WaveformWidget(
                key: const ValueKey('studio-dock-live-waveform'),
                subtitles: widget.subtitles,
                playbackPosition: position,
                onSeek: widget.playback.seek,
                isVideoPlaying: () => widget.playback.playing.value,
                height: size.maxHeight,
                compact: true,
                compactToolbarBuilder: (context, controls) => SizedBox(
                  height: 32,
                  child: toolbar(controls: controls, position: position),
                ),
                enableTimeEditing: widget.onApplyTimeEdit != null &&
                    widget.onAddLineConfirmed != null,
                onApplyTimeEdit: widget.onApplyTimeEdit,
                onAddLineConfirmed: widget.onAddLineConfirmed,
                onSubtitleHighlight: widget.onSubtitleHighlight,
                // Only the desktop host can persist waveform time edits.
                subtitleCollectionId: null,
                sessionId: null,
              )),
            ),
          ),
        )
      else
        const Expanded(child: Center(
          child: Text('Waveform hidden — use Generate to show it.',
              key: ValueKey('studio-waveform-hidden')),
        )),
    ]);
  }
}

/// Focusable controls above the existing waveform, independent of media_kit.
class StudioDockWaveformToolbar extends StatelessWidget {
  const StudioDockWaveformToolbar({
    super.key,
    required this.visible,
    required this.canRegenerate,
    required this.busy,
    required this.onToggleVisibility,
    required this.onRegenerate,
    this.compactControls,
    this.position,
  });

  final bool visible;
  final bool canRegenerate;
  final bool busy;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRegenerate;
  final Widget? compactControls;
  final Duration? position;

  static String formatTime(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => Row(children: [
    const SizedBox(width: 4),
    Icon(Icons.graphic_eq, size: 15, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 6),
    const Text('WAVEFORM', style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: .8)),
    if (compactControls != null) ...[
      const SizedBox(width: 8),
      Expanded(child: compactControls!),
    ] else const Spacer(),
    if (position != null && size.maxWidth >= 570) ...[
      const SizedBox(width: 8),
      Text(formatTime(position!),
          key: const ValueKey('studio-waveform-timecode'),
          style: const TextStyle(fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()])),
    ],
    if (size.maxWidth < 650) IconButton(
      key: const ValueKey('studio-waveform-visibility'),
      tooltip: visible ? 'Hide waveform' : 'Show waveform',
      onPressed: busy ? null : onToggleVisibility,
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 17),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
    ) else TextButton.icon(
      key: const ValueKey('studio-waveform-visibility'),
      onPressed: busy ? null : onToggleVisibility,
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 15),
      label: Text(visible ? 'Hide' : 'Generate'),
    ),
    if (size.maxWidth < 650) IconButton(
      key: const ValueKey('studio-waveform-regenerate'),
      tooltip: busy ? 'Loading waveform…' : 'Regenerate waveform',
      onPressed: canRegenerate && !busy ? onRegenerate : null,
      icon: busy
          ? const SizedBox(width: 15, height: 15,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, size: 17),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
    ) else TextButton.icon(
      key: const ValueKey('studio-waveform-regenerate'),
      onPressed: canRegenerate && !busy ? onRegenerate : null,
      icon: const Icon(Icons.refresh, size: 15),
      label: Text(busy ? 'Loading…' : 'Regenerate'),
    ),
    const SizedBox(width: 4),
  ]));
}
