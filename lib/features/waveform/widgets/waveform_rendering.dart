part of 'waveform_widget.dart';

extension _WaveformRendering on WaveformWidgetState {
  Widget _buildEmptyState() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No waveform loaded',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(WaveformLoading state) {
    final brightness = Theme.of(context).brightness;

    final loaderColor = brightness == Brightness.dark
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loader13 widget
            SizedBox(
              height: 60,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return _BouncingDot(
                      delay: Duration(milliseconds: i * 100),
                      color: loaderColor,
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Generating waveform...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WaveformError state) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading waveform',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.height - 140, // Reserve space for icon and title
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformView(WaveformReady state) {
    // Update viewport width when widget size changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          // Account for border and vertical zoom bar width
          final width = renderBox.size.width - 50; // 50px for vertical zoom bar and borders
          if (width != state.viewportWidth) {
            ref.read(waveformControllerProvider.notifier).dispatch(UpdateViewportWidth(width));
          }
        }
      }
    });

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Horizontal bar with zoom controls on left and menu button box on right
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate width for left section (total width - menu button width)
              final leftSectionWidth = constraints.maxWidth - 48;
              final isMobile = MediaQuery.of(context).size.width <= 600;
              final spacing = isMobile ? 1.0 : 8.0;
              final smallSpacing = isMobile ? 0.0 : 4.0;
              
              return Row(
                children: [
                  // Left side: Narrower zoom controls bar
                  SizedBox(
                    width: leftSectionWidth,
                    child: Container(
                      height: 40,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Zoom out button (- icon for less detail)
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        tooltip: 'Zoom Out',
                        onPressed: state.canZoomOut
                            ? () => ref.read(waveformControllerProvider.notifier).dispatch(const ZoomOut())
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      // Zoom slider (only on desktop/tablet)
                      if (MediaQuery.of(context).size.width > 600)
                        SizedBox(
                          width: 120,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: Colors.orange,
                              inactiveTrackColor: Colors.grey[700],
                              thumbColor: Colors.orange,
                            ),
                            child: Slider(
                              // Invert value: slider right (max) = index 0 (zoomed in), slider left (min) = max index (zoomed out)
                              value: (state.buffer.zoomLevelCount - 1 - state.currentZoomIndex).toDouble(),
                              min: 0,
                              max: (state.buffer.zoomLevelCount - 1).toDouble(),
                              divisions: state.buffer.zoomLevelCount > 1 ? state.buffer.zoomLevelCount - 1 : null,
                              onChanged: state.buffer.zoomLevelCount > 1 ? (value) {
                                // Convert slider value back to zoom index
                                final newIndex = state.buffer.zoomLevelCount - 1 - value.round();
                                final diff = newIndex - state.currentZoomIndex;
                                if (diff < 0) {
                                  // Index decreased = zoom in (more detail)
                                  for (int i = 0; i < -diff; i++) {
                                    ref.read(waveformControllerProvider.notifier).dispatch(const ZoomIn());
                                  }
                                } else if (diff > 0) {
                                  // Index increased = zoom out (less detail)
                                  for (int i = 0; i < diff; i++) {
                                    ref.read(waveformControllerProvider.notifier).dispatch(const ZoomOut());
                                  }
                                }
                              } : null,
                            ),
                          ),
                        ),
                      if (MediaQuery.of(context).size.width > 600) SizedBox(width: smallSpacing),
                      // Zoom in button (+ icon for more detail)
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Zoom In',
                        onPressed: state.canZoomIn
                            ? () => ref.read(waveformControllerProvider.notifier).dispatch(const ZoomIn())
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      SizedBox(width: spacing),
                      // Zoom level indicator (as percentage)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 2 : 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          // Convert to percentage: 0% = most zoomed out, 100% = most zoomed in
                          // Since lower index = more detail, we reverse: (maxIndex - currentIndex) / maxIndex * 100
                          '${(((state.buffer.zoomLevelCount - 1 - state.currentZoomIndex) / (state.buffer.zoomLevelCount - 1)) * 100).round()}%',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing),
                      // Vertical divider
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      SizedBox(width: spacing),
                      // Overlap toggle button
                      IconButton(
                        icon: Icon(
                          Icons.swap_horiz,
                          size: 20,
                          color: state.allowOverlap ? Colors.orange : Colors.grey,
                        ),
                        tooltip: state.allowOverlap ? 'Overlap Enabled' : 'Overlap Disabled',
                        onPressed: () => ref.read(waveformControllerProvider.notifier).dispatch(const ToggleOverlapMode()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      if (smallSpacing > 0) SizedBox(width: smallSpacing),
                      // Magnet snap button
                      IconButton(
                        icon: SvgPicture.asset(
                          'assets/magnet-solid.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            state.magnetSnapEnabled ? Colors.red : Colors.grey,
                            BlendMode.srcIn,
                          ),
                        ),
                        tooltip: state.magnetSnapEnabled ? 'Magnet Snap Enabled' : 'Magnet Snap Disabled',
                        onPressed: () => ref.read(waveformControllerProvider.notifier).dispatch(const ToggleMagnetSnap()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      if (smallSpacing > 0) SizedBox(width: smallSpacing),
                      // Add line button (hidden when in edit or add line mode)
                      if (!state.isEditMode && !state.isAddLineMode)
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: Color(0xFF00695C), // Dark teal - matches add line overlay
                          ),
                          tooltip: 'Add New Subtitle Line',
                          onPressed: () => _triggerAddLineMode(state),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      if (!state.isEditMode && !state.isAddLineMode && smallSpacing > 0) 
                        SizedBox(width: smallSpacing),
                      SizedBox(width: spacing),
                      // Apply and Cancel buttons (shown when in edit mode)
                      if (state.isEditMode) ...[
                        IconButton(
                          icon: const Icon(Icons.check, size: 20, color: Colors.green),
                          tooltip: 'Apply Time Changes',
                          onPressed: () => _applyTimeChanges(state),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.red),
                          tooltip: 'Cancel Edit Mode',
                          onPressed: () => ref.read(waveformControllerProvider.notifier).dispatch(const ExitTimeEditMode()),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                      ],
                      // Add and Close buttons (shown when in add line mode)
                      if (state.isAddLineMode) ...[
                        IconButton(
                          icon: const Icon(Icons.check, size: 20, color: Colors.green),
                          tooltip: 'Add Line with Selected Times',
                          onPressed: () => _confirmAddLine(state),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.red),
                          tooltip: 'Cancel Add Line Mode',
                          onPressed: () => ref.read(waveformControllerProvider.notifier).dispatch(const ExitAddLineMode()),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                      ],
                    ],
                  ),
                ),
              ),
              // Right side: Menu button box (matches vertical zoom bar width)
              Container(
                width: 48,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
                child: Center(
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Waveform Options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onSelected: (value) {
                      if (value == 'toggle_autoscroll') {
                        ref.read(waveformControllerProvider.notifier).dispatch(const ToggleAutoScroll());
                      } else if (value == 'settings') {
                        _openWaveformSettings();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'toggle_autoscroll',
                        child: Row(
                          children: [
                            Icon(
                              state.autoScroll ? Icons.sync : Icons.sync_disabled,
                              size: 20,
                              color: state.autoScroll ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(state.autoScroll ? 'Disable Auto-Scroll' : 'Enable Auto-Scroll'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 12),
                            Text('Waveform Settings'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                ],
              );
            },
          ),
          // Waveform display with vertical zoom on the right
          Expanded(
            child: Row(
              children: [
                // Left side: Waveform with overlaid subtitle boxes
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Stack(
                      children: [
                        // Waveform background with tap detection
                        ClipRect(
                          child: Listener(
                            onPointerSignal: (event) {
                              if (event is PointerScrollEvent) {
                                _handleScroll(event, state);
                              }
                            },
                            onPointerDown: (event) {
                              // Handle mouse clicks (primary button for double-click, secondary for add line mode)
                              if (event.kind == PointerDeviceKind.mouse) {
                                if (event.buttons == 1) {
                                  // Primary button (left click)
                                  _handleMouseClick(event, state);
                                } else if (event.buttons == 2) {
                                  // Secondary button (right click) - prepare for add line mode
                                  _handleMouseRightClick(event, state);
                                }
                              }
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _handleTapUp(details, state),
                              onLongPressStart: (details) => _handleLongPressStart(details, state),
                              onLongPressMoveUpdate: (details) => _handleLongPressMoveUpdate(details, state),
                              onLongPressEnd: (details) => _handleLongPressEnd(details, state),
                              onPanStart: (details) => _handleWaveformPanStart(details, state),
                              onPanUpdate: (details) => _handleWaveformPanUpdate(details, state),
                              onPanEnd: (details) => _handleWaveformPanEnd(),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: WaveformPainter(
                                  zoomLevel: state.currentZoomLevel,
                                  scrollOffset: state.scrollPosition,
                                  playbackPosition: state.playbackPosition,
                                  subtitles: _currentSubtitles,
                                  sampleRate: state.buffer.sampleRate,
                                  samplesPerPixel: state.samplesPerPixel,
                                  verticalZoom: state.verticalZoom,
                                  waveformColor: _getWaveformColor(context),
                                  subtitleColor: Theme.of(context).colorScheme.primary,
                                  playbackColor: Colors.red,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  showSubtitlesOnly: false,
                                  showWaveformOnly: true,
                                  subtitleHighlightColor: _getSubtitleHighlightColor(context),
                                  showPlaybackIndicator: true,
                                  isEditMode: state.isEditMode,
                                  editingSubtitleIndex: state.editingSubtitleIndex,
                                  tempStartTime: state.tempStartTime,
                                  tempEndTime: state.tempEndTime,
                                  isAddLineMode: state.isAddLineMode,
                                  addLineStartTime: state.addLineStartTime,
                                  addLineEndTime: state.addLineEndTime,
                                  highlightedSubtitleIndex: widget.highlightedSubtitleIndex,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Subtitle boxes overlaid on top (visual only, no interaction)
                        IgnorePointer(
                          child: ClipRect(
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: WaveformPainter(
                                  zoomLevel: state.currentZoomLevel,
                                  scrollOffset: state.scrollPosition,
                                  playbackPosition: state.playbackPosition,
                                  subtitles: _currentSubtitles,
                                  sampleRate: state.buffer.sampleRate,
                                  samplesPerPixel: state.samplesPerPixel,
                                  verticalZoom: state.verticalZoom,
                                  waveformColor: _getWaveformColor(context),
                                  subtitleColor: Theme.of(context).colorScheme.primary,
                                  playbackColor: Colors.red,
                                  backgroundColor: Colors.transparent,
                                  showSubtitlesOnly: true,
                                  showWaveformOnly: false,
                                  subtitleHighlightColor: _getSubtitleHighlightColor(context),
                                  showPlaybackIndicator: false,
                                  isEditMode: state.isEditMode,
                                  editingSubtitleIndex: state.editingSubtitleIndex,
                                tempStartTime: state.tempStartTime,
                                tempEndTime: state.tempEndTime,
                                isAddLineMode: state.isAddLineMode,
                                addLineStartTime: state.addLineStartTime,
                                addLineEndTime: state.addLineEndTime,
                                highlightedSubtitleIndex: widget.highlightedSubtitleIndex,
                              ),
                            ),
                          ),
                        ),
                        // Time position overlay
                        Positioned(
                          left: 12,
                          bottom: 1,
                          child: GestureDetector(
                            onTap: () => _copyTimeToClipboard(state),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDisplayTime(state),
                                style: TextStyle(
                                  color: Color(0x99EE9B00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  fontFamily: GoogleFonts.spaceMono().fontFamily,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right side: Vertical zoom control
                Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Zoom in button (increase amplitude)
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        tooltip: 'Increase Amplitude',
                        onPressed: state.verticalZoom < 3.0
                            ? () {
                                final newZoom = (state.verticalZoom + 0.1).clamp(0.5, 3.0);
                                ref.read(waveformControllerProvider.notifier).dispatch(UpdateVerticalZoom(newZoom));
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(state.verticalZoom * 100).round()}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      // Zoom out button (decrease amplitude)
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        tooltip: 'Decrease Amplitude',
                        onPressed: state.verticalZoom > 0.5
                            ? () {
                                final newZoom = (state.verticalZoom - 0.1).clamp(0.5, 3.0);
                                ref.read(waveformControllerProvider.notifier).dispatch(UpdateVerticalZoom(newZoom));
                              }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get waveform color based on current theme
  Color _getWaveformColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.dark) {
      return Colors.blue.shade400;
    }
    
    // For light mode, use theme secondary color
    return Theme.of(context).colorScheme.secondary;
  }

  /// Get subtitle highlight color for waveform background regions
  Color _getSubtitleHighlightColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    // Use a more vibrant contrasting color
    if (brightness == Brightness.dark) {
      return Colors.amber.shade600.withValues(alpha: 0.4);
    }
    
    return Colors.orange.shade400.withValues(alpha: 0.45);
  }
}

/// Bouncing dot widget for Loader13-style animation
class _BouncingDot extends StatefulWidget {
  final Duration delay;
  final Color color;

  const _BouncingDot({
    required this.delay,
    required this.color,
  });

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -30 * _controller.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
