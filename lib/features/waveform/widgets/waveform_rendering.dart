part of 'waveform_widget.dart';

extension _WaveformRendering on WaveformWidgetState {
  Widget _buildEmptyState() {
    if (widget.compact) {
      return Center(child: Text('No waveform loaded',
        style: TextStyle(fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No waveform loaded',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(WaveformLoading state) {
    if (widget.compact) {
      final colors = Theme.of(context).colorScheme;
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(height: 31, child: WaveformLoadingBars(
                fillFraction: state.waveformFillFraction,
                activeColor: colors.primary,
                inactiveColor: colors.onSurfaceVariant.withValues(alpha: 0.18),
              )),
            ),
          ),
          const SizedBox(height: 5),
          Text(state.progress >= 0.35
              ? 'Preparing waveform…' : 'Generating waveform…',
              style: const TextStyle(fontSize: 11)),
        ],
      ));
    }
    final colors = Theme.of(context).colorScheme;
    final preparing = state.progress >= 0.35;
    
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SizedBox(
                  height: widget.height < 160 ? 36 : 48,
                  width: double.infinity,
                  child: WaveformLoadingBars(
                    fillFraction: state.waveformFillFraction,
                    activeColor: colors.primary,
                    inactiveColor: colors.onSurfaceVariant.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              preparing
                  ? 'Preparing waveform...'
                  : 'Generating waveform...',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!preparing && state.processedAudioTime != null && widget.height >= 160) ...[
              const SizedBox(height: 6),
              Text(
                state.totalAudioTime != null && state.totalAudioTime! > Duration.zero
                    ? '${WaveformDecodeProgress.format(state.processedAudioTime!)} / '
                      '${WaveformDecodeProgress.formatTime(state.totalAudioTime!)}'
                    : WaveformDecodeProgress.format(state.processedAudioTime!),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WaveformError state) {
    if (widget.compact) {
      return Center(child: Tooltip(
        message: state.message,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 16,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 6),
          Flexible(child: Text('Waveform unavailable · inspect audio source',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11))),
        ]),
      ));
    }
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading waveform',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildCompactToolbar(WaveformReady state) => LayoutBuilder(
    builder: (context, limits) => SizedBox(
    height: 28,
    child: Row(children: [
      IconButton(
        key: const ValueKey('waveform-compact-zoom-out'),
        tooltip: 'Zoom waveform out',
        icon: const Icon(Icons.remove, size: 16),
        onPressed: state.canZoomOut
            ? () => ref.read(waveformControllerProvider.notifier)
                .dispatch(const ZoomOut()) : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
      ),
      IconButton(
        key: const ValueKey('waveform-compact-zoom-in'),
        tooltip: 'Zoom waveform in',
        icon: const Icon(Icons.add, size: 16),
        onPressed: state.canZoomIn
            ? () => ref.read(waveformControllerProvider.notifier)
                .dispatch(const ZoomIn()) : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
      ),
      if (limits.maxWidth >= 355) ...[
        IconButton(
          key: const ValueKey('waveform-compact-vertical-zoom-out'),
          tooltip: 'Reduce waveform amplitude (vertical scale)',
          icon: const StudioAssetIcon(StudioAssetIcons.amplitudeDecrease,
              size: 17),
          onPressed: state.verticalZoom > .5
              ? () => ref.read(waveformControllerProvider.notifier)
                  .dispatch(UpdateVerticalZoom(
                      (state.verticalZoom - .25).clamp(.5, 8.0)))
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
        ),
        Text('${(state.verticalZoom * 100).round()}%',
            style: const TextStyle(fontSize: 10)),
        IconButton(
          key: const ValueKey('waveform-compact-vertical-zoom-in'),
          tooltip: 'Amplify waveform (vertical scale)',
          icon: const StudioAssetIcon(StudioAssetIcons.amplitudeIncrease,
              size: 17),
          onPressed: state.verticalZoom < 8
              ? () => ref.read(waveformControllerProvider.notifier)
                  .dispatch(UpdateVerticalZoom(
                      (state.verticalZoom + .25).clamp(.5, 8.0)))
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
        ),
      ],
      const Spacer(),
      if (widget.enableTimeEditing && limits.maxWidth >= 365) ...[
        IconButton(
          key: const ValueKey('waveform-compact-overlap'),
          tooltip: state.allowOverlap ? 'Disable overlap' : 'Allow overlap',
          icon: Icon(Icons.swap_horiz, size: 16,
              color: state.allowOverlap ? WaveformControlColors.overlap : null),
          onPressed: () => ref.read(waveformControllerProvider.notifier)
              .dispatch(const ToggleOverlapMode()),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
        ),
        IconButton(
          key: const ValueKey('waveform-compact-magnet'),
          tooltip: state.magnetSnapEnabled ? 'Disable magnet snap' : 'Enable magnet snap',
          icon: SvgPicture.asset('assets/magnet-solid.svg',
              width: 16, height: 16,
              colorFilter: ColorFilter.mode(
                state.magnetSnapEnabled
                    ? WaveformControlColors.magnet
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                BlendMode.srcIn)),
          onPressed: () => ref.read(waveformControllerProvider.notifier)
              .dispatch(const ToggleMagnetSnap()),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
        ),
      ],
      if (widget.enableTimeEditing) ...[
        if (state.isEditMode || state.isAddLineMode) ...[
          IconButton(
            key: const ValueKey('waveform-compact-apply'),
            tooltip: state.isEditMode ? 'Apply Time Changes' : 'Add Line with Selected Times',
            icon: const Icon(Icons.check, size: 18),
            onPressed: () {
              if (state.isEditMode) {
                _applyTimeChanges(state);
              } else {
                _confirmAddLine(state);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
          ),
          IconButton(
            key: const ValueKey('waveform-compact-cancel'),
            tooltip: state.isEditMode ? 'Cancel Time Edit' : 'Cancel New Subtitle',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(waveformControllerProvider.notifier)
                .dispatch(state.isEditMode
                    ? const ExitTimeEditMode() : const ExitAddLineMode()),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
          ),
        ] else IconButton(
          key: const ValueKey('waveform-compact-add-line'),
          tooltip: 'Add New Subtitle Line',
          icon: const Icon(Icons.add_circle_outline, size: 18),
          onPressed: () => _triggerAddLineMode(state),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
        ),
      ],
      IconButton(
        tooltip: state.autoScroll ? 'Disable waveform auto-scroll'
            : 'Enable waveform auto-scroll',
        icon: Icon(state.autoScroll ? Icons.sync : Icons.sync_disabled,
            size: 16),
        onPressed: () => ref.read(waveformControllerProvider.notifier)
            .dispatch(const ToggleAutoScroll()),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 26),
      ),
    ]),
  ));

  Widget _buildWaveformView(WaveformReady state) {
    final editing = state.isEditMode || state.isAddLineMode;
    if (widget.compact && editing && !_wasTimeEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _timeEditFocus.requestFocus();
      });
    }
    _wasTimeEditing = editing;
    // Update viewport width when widget size changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          // Account for border and vertical zoom bar width
          final width = (renderBox.size.width -
              (widget.compact ? 2 : 50)).clamp(1.0, double.infinity).toDouble();
          if (width != state.viewportWidth) {
            ref.read(waveformControllerProvider.notifier).dispatch(UpdateViewportWidth(width));
          }
        }
      }
    });

    return Focus(
      focusNode: _timeEditFocus,
      onKeyEvent: (node, event) => _handleTimeEditKey(node, event, state),
      child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // The desktop band has only ~13% of available vertical space.
          // Keep waveform interaction area usable without the full toolbar.
          if (widget.compact)
            widget.compactToolbarBuilder?.call(
                context, _buildCompactToolbar(state)) ??
                _buildCompactToolbar(state)
          else LayoutBuilder(
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                              activeTrackColor: WaveformControlColors.zoom,
                              inactiveTrackColor: Theme.of(context).colorScheme.outline,
                              thumbColor: WaveformControlColors.zoom,
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
                          '${state.buffer.zoomLevelCount > 1 ? (((state.buffer.zoomLevelCount - 1 - state.currentZoomIndex) / (state.buffer.zoomLevelCount - 1)) * 100).round() : 100}%',
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
                          color: state.allowOverlap ? WaveformControlColors.overlap : Theme.of(context).colorScheme.onSurfaceVariant,
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
                            state.magnetSnapEnabled ? WaveformControlColors.magnet : Theme.of(context).colorScheme.onSurfaceVariant,
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
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: WaveformControlColors.addLine,
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
                          icon: Icon(Icons.check, size: 20, color: WaveformControlColors.confirm),
                          tooltip: 'Apply Time Changes',
                          onPressed: () => _applyTimeChanges(state),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: WaveformControlColors.cancel),
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
                          icon: Icon(Icons.check, size: 20, color: WaveformControlColors.confirm),
                          tooltip: 'Add Line with Selected Times',
                          onPressed: () => _confirmAddLine(state),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        if (smallSpacing > 0) SizedBox(width: smallSpacing),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: WaveformControlColors.cancel),
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
                        height: widget.compact ? 34 : kMinInteractiveDimension,
                        value: 'toggle_autoscroll',
                        child: Row(
                          children: [
                            Icon(
                              state.autoScroll ? Icons.sync : Icons.sync_disabled,
                              size: 20,
                              color: state.autoScroll ? WaveformControlColors.autoScroll : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Text(state.autoScroll ? 'Disable Auto-Scroll' : 'Enable Auto-Scroll'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        height: widget.compact ? 34 : kMinInteractiveDimension,
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
                                _handleScroll(event);
                              }
                            },
                            onPointerDown: (event) {
                              if (widget.compact && editing &&
                                  !_timeEditFocus.hasFocus) {
                                _timeEditFocus.requestFocus();
                              }
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
                              onPanCancel: _handleWaveformPanCancel,
                              child: Builder(
                                builder: (context) {
                                  final waveformPainter = WaveformPainter(
                                  zoomLevel: state.currentZoomLevel,
                                  tileSource: _tilesFor(state),
                                  scrollOffset: state.scrollPosition,
                                  playbackPosition: state.playbackPosition,
                                  subtitles: _currentSubtitles,
                                  sampleRate: state.buffer.sampleRate,
                                  samplesPerPixel: state.samplesPerPixel,
                                  verticalZoom: state.verticalZoom,
                                  waveformColor: _getWaveformColor(context),
                                  subtitleColor: WaveformControlColors.subtitleOverlay,
                                  addLineColor: WaveformControlColors.addLine,
                                  playbackColor: WaveformControlColors.playhead,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  showTimeRuler: widget.compact,
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
                                );
                                  if (!widget.useLayeredWaveform) {
                                    return CustomPaint(
                                      size: Size.infinite,
                                      painter: waveformPainter,
                                    );
                                  }
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      RepaintBoundary(
                                        child: CustomPaint(
                                          size: Size.infinite,
                                          painter: waveformPainter.forLayer(
                                            WaveformPaintLayer.scenery),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: CustomPaint(
                                          size: Size.infinite,
                                          painter: waveformPainter.forLayer(
                                            WaveformPaintLayer.overlays),
                                        ),
                                      ),
                                    ],
                                  );
                                },
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
                                  tileSource: _tilesFor(state),
                                  scrollOffset: state.scrollPosition,
                                  playbackPosition: state.playbackPosition,
                                  subtitles: _currentSubtitles,
                                  sampleRate: state.buffer.sampleRate,
                                  samplesPerPixel: state.samplesPerPixel,
                                  verticalZoom: state.verticalZoom,
                                  waveformColor: _getWaveformColor(context),
                                  subtitleColor: WaveformControlColors.subtitleOverlay,
                                  addLineColor: WaveformControlColors.addLine,
                                  playbackColor: WaveformControlColors.playhead,
                                  backgroundColor: Colors.transparent,
                                  showTimeRuler: widget.compact,
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
                                  color: WaveformControlColors.timeReadout,
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
                // Compact Studio Dock omits the full-height amplitude strip.
                if (!widget.compact) Container(
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
                        icon: const StudioAssetIcon(StudioAssetIcons.amplitudeIncrease,
                            size: 19),
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
                        icon: const StudioAssetIcon(StudioAssetIcons.amplitudeDecrease,
                            size: 19),
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
      ),
    );
  }

  Color _getWaveformColor(BuildContext context) =>
      WaveformControlColors.waveform(Theme.of(context));

  Color _getSubtitleHighlightColor(BuildContext context) =>
      WaveformControlColors.subtitleHighlight(Theme.of(context));
}
