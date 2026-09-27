import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_event.dart';
import 'package:subtitle_studio/features/waveform/state/waveform_state.dart';
import 'package:subtitle_studio/features/waveform/providers/waveform_controller.dart';

/// Toolbar widget for waveform controls.
class WaveformToolbar extends ConsumerWidget {
  final VoidCallback onLoadAudio;

  const WaveformToolbar({
    super.key,
    required this.onLoadAudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waveformControllerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildLoadButton(context, state),
          const SizedBox(width: 8),
          if (state is WaveformReady) ...[
            const VerticalDivider(),
            const SizedBox(width: 8),
            _buildZoomControls(context, ref, state),
            const SizedBox(width: 8),
            const VerticalDivider(),
            const SizedBox(width: 8),
            _buildAutoScrollToggle(context, ref, state),
            const Spacer(),
            _buildInfoDisplay(context, state),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadButton(BuildContext context, WaveformState state) {
    final isLoading = state is WaveformLoading;

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onLoadAudio,
      icon: Icon(
        isLoading ? Icons.hourglass_empty : Icons.audio_file,
        size: 18,
      ),
      label: Text(
        isLoading ? 'Loading...' : 'Load Audio',
        style: const TextStyle(fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildZoomControls(
    BuildContext context,
    WidgetRef ref,
    WaveformReady state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: state.canZoomOut
              ? () => ref
                  .read(waveformControllerProvider.notifier)
                  .dispatch(const ZoomOut())
              : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Zoom Out',
          iconSize: 20,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${state.currentZoomIndex + 1}/${state.buffer.zoomLevelCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          onPressed: state.canZoomIn
              ? () => ref
                  .read(waveformControllerProvider.notifier)
                  .dispatch(const ZoomIn())
              : null,
          icon: const Icon(Icons.add),
          tooltip: 'Zoom In',
          iconSize: 20,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildAutoScrollToggle(
    BuildContext context,
    WidgetRef ref,
    WaveformReady state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: state.autoScroll,
          onChanged: (_) => ref
              .read(waveformControllerProvider.notifier)
              .dispatch(const ToggleAutoScroll()),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Text(
          'Auto-scroll',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildInfoDisplay(BuildContext context, WaveformReady state) {
    final durationText = _formatDuration(state.buffer.duration);
    final samplesPerPixel = state.samplesPerPixel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$durationText • $samplesPerPixel samp/px',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
