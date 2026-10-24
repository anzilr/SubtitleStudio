import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/widgets/waveform_widget.dart';

import 'studio_dock_playback_link.dart';

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
    ++_loadRevision; // Cancel an older, post-frame automatic load.
    setState(() {
      _regenerating = true;
      _commandError = null;
      _waveformVisible = true;
    });
    try {
      // Match mobile cache invalidation and retain the selected audio stream.
      await ref.read(waveformPreferencesRepositoryProvider)
          .clearWaveformCache(collection);
      if (!mounted || widget.videoPath != path ||
          widget.collectionId != collection) return;
      final current = widget.playback.audio.value;
      if (current.status != StudioDockAudioStatus.ready ||
          current.trackId != selection.trackId ||
          current.streamSelector != selection.streamSelector) return;
      final controller = ref.read(waveformControllerProvider.notifier);
      await controller.dispatch(const ClearWaveform());
      if (!mounted) return;
      await controller.dispatch(LoadAudioFile(path,
        subtitleCollectionId: collection,
        audioTrackId: selection.streamSelector,
        useSavedAudioTrackPreference: false,
      ));
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limits) => Column(children: [
      SizedBox(
        height: 32,
        child: ValueListenableBuilder<StudioDockAudioSource>(
          valueListenable: widget.playback.audio,
          builder: (context, source, _) => StudioDockWaveformToolbar(
            visible: _waveformVisible,
            canRegenerate: source.status == StudioDockAudioStatus.ready,
            busy: _regenerating,
            onToggleVisibility: () => setState(() {
              _waveformVisible = !_waveformVisible;
              _commandError = null;
            }),
            onRegenerate: () => unawaited(_regenerateWaveform()),
          ),
        ),
      ),
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
    ]),
  );
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
  });

  final bool visible;
  final bool canRegenerate;
  final bool busy;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) => Row(children: [
    const SizedBox(width: 8),
    const Icon(Icons.graphic_eq, size: 15),
    const SizedBox(width: 6),
    const Expanded(child: Text('Waveform', maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    TextButton.icon(
      key: const ValueKey('studio-waveform-visibility'),
      onPressed: busy ? null : onToggleVisibility,
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 15),
      label: Text(visible ? 'Hide' : 'Generate'),
    ),
    TextButton.icon(
      key: const ValueKey('studio-waveform-regenerate'),
      onPressed: canRegenerate && !busy ? onRegenerate : null,
      icon: const Icon(Icons.refresh, size: 15),
      label: Text(busy ? 'Loading…' : 'Regenerate'),
    ),
    const SizedBox(width: 8),
  ]);
}
