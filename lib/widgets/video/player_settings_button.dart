part of '../video_player_widget.dart';

class _SettingsButton extends StatefulWidget {
  const _SettingsButton();

  @override
  _SettingsButtonState createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final videoPlayerState = context.findAncestorStateOfType<VideoPlayerWidgetState>();
    
    if (videoPlayerState == null) {
      return const SizedBox.shrink();
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          _showSettingsMenu(context, videoPlayerState);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32, // Increased size for better usability
          height: 32, // Increased size for better usability
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.tune, // Configuration/settings icon
            color: _isHovered ? Colors.blue.shade200 : Colors.white,
            size: 22, // Increased icon size
            shadows: const [
              Shadow(
                blurRadius: 3.0,
                color: Colors.black,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, VideoPlayerWidgetState videoPlayerState) {
    // Capture parent context so inner builders can call dialogs/snackbars safely after the sheet is popped
    final BuildContext parentContext = context;
    // Show settings sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Use a distinct name for the sheet's builder context to avoid shadowing the parent
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            // Dynamic color variables for adaptive theming
            final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
            final primaryColor = Theme.of(sheetContext).primaryColor;
            final surfaceColor = Theme.of(sheetContext).colorScheme.surface;
            final onSurfaceColor = Theme.of(sheetContext).colorScheme.onSurface;
            final mutedColor = onSurfaceColor.withValues(alpha: 0.6);

            return Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Video Settings',
                                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Adjust playback and subtitle settings',
                                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
              
                      
                      // Playback Speed Section
                      StatefulBuilder(
                        builder: (BuildContext context, StateSetter setSpeedState) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.speed,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Playback Speed',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${videoPlayerState.getCurrentSpeed()}x',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<double>(
                                  onSelected: (double value) {
                                    videoPlayerState.setPlaybackSpeed(value);
                                    setSpeedState(() {}); // Trigger rebuild of this section
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: onSurfaceColor.withValues(alpha: 0.12),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.6),
                                      size: 18,
                                    ),
                                  ),
                                  itemBuilder: (BuildContext context) {
                                    final speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
                                    return speedOptions.map((double speed) {
                                      final isSelected = videoPlayerState.getCurrentSpeed() == speed;
                                      String label = '${speed}x';
                                      if (speed == 1.0) label = '1x (Normal)';
                                      
                                      return PopupMenuItem<double>(
                                        value: speed,
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                              color: isSelected ? primaryColor : onSurfaceColor.withValues(alpha: 0.6),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: isSelected ? primaryColor : onSurfaceColor,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      // Audio Track Section
                      Builder(
                        builder: (context) {
                          final availableTracks = videoPlayerState.getAvailableAudioTracks();
                          // Exclude pseudo-tracks 'auto' and 'no' when reporting available tracks
                          final realTracks = availableTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
                          final hasMultipleTracks = realTracks.length > 1;
                          
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.audiotrack,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Audio Track',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        hasMultipleTracks 
                                          ? '${realTracks.length} tracks available'
                                          : 'Default track',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                hasMultipleTracks 
                                  ? PopupMenuButton<AudioTrack>(
                                      onSelected: (AudioTrack track) async {
                                        await videoPlayerState.setAudioTrack(track);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          Icons.arrow_drop_down,
                                          color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.6),
                                          size: 18,
                                        ),
                                      ),
                                      itemBuilder: (BuildContext context) {
                                        final currentTrack = videoPlayerState.getCurrentAudioTrack();
                                        return availableTracks.map((AudioTrack track) {
                                          final isSelected = currentTrack?.id == track.id;
                                          
                                          // Get track display name
                                          String trackName = 'Track ${track.id}';
                                          if (track.id == 'auto') {
                                            trackName = 'Auto';
                                          } else if (track.id == 'no') {
                                            trackName = 'Off';
                                          } else if (track.title?.isNotEmpty == true) {
                                            trackName = track.title!;
                                          } else if (track.language?.isNotEmpty == true) {
                                            trackName = 'Track ${track.id} (${track.language})';
                                          }
                                          
                                          return PopupMenuItem<AudioTrack>(
                                            value: track,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                                  color: isSelected ? Colors.orange : onSurfaceColor.withValues(alpha: 0.6),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    trackName,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.orange : onSurfaceColor,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList();
                                      },
                                    )
                                  : Icon(
                                      Icons.not_interested,
                                      color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.3),
                                      size: 18,
                                    ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Custom font loader
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            // Close sheet first (use sheetContext) then call pick using captured parentContext so lookups are safe
                            Navigator.pop(sheetContext);
                            await videoPlayerState._pickAndSaveFont(parentContext);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.font_download,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Load Custom Subtitle Font',
                                        style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        videoPlayerState._subtitleFontFilePath != null
                                            ? videoPlayerState._subtitleFontFilePath!.split(Platform.pathSeparator).last
                                            : 'No custom font',
                                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Theme.of(sheetContext).iconTheme.color?.withValues(alpha: 0.3),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Font size adjustment with expandable preview
                      _FontSizeExpandableControl(
                        videoPlayerState: videoPlayerState,
                        primaryColor: primaryColor,
                        onSurfaceColor: onSurfaceColor,
                        isDark: isDark,
                        sheetContext: sheetContext,
                      ),
                      const SizedBox(height: 16),
                      // Subtitle background toggle
                      StatefulBuilder(
                        builder: (
                          BuildContext context,
                          StateSetter setSheetState,
                        ) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final newValue =
                                    !videoPlayerState._showSubtitleBackground;
                                await PreferencesModel.setShowSubtitleBackground(
                                  newValue,
                                );
                                videoPlayerState.setState(() {
                                  videoPlayerState._showSubtitleBackground =
                                      newValue;
                                });
                                setSheetState(() {}); // Update sheet UI
                                videoPlayerState._updateActiveSubtitles(
                                  videoPlayerState.getCurrentPosition(),
                                );
                                videoPlayerState._fullscreenOverlay
                                    ?.markNeedsBuild();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.text_fields,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Subtitle Background',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            videoPlayerState
                                                    ._showSubtitleBackground
                                                ? 'Enabled'
                                                : 'Disabled',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(sheetContext)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value:
                                          videoPlayerState
                                              ._showSubtitleBackground,
                                      onChanged: (value) async {
                                        await PreferencesModel.setShowSubtitleBackground(
                                          value,
                                        );
                                        videoPlayerState.setState(() {
                                          videoPlayerState
                                              ._showSubtitleBackground = value;
                                        });
                                        setSheetState(() {}); // Update sheet UI
                                        videoPlayerState._updateActiveSubtitles(
                                          videoPlayerState.getCurrentPosition(),
                                        );
                                        videoPlayerState._fullscreenOverlay
                                            ?.markNeedsBuild();
                                      },
                                      activeThumbColor: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Primary subtitle position adjustment
                      StatefulBuilder(
                        builder: (BuildContext context, StateSetter setSheetState) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: onSurfaceColor.withValues(alpha: 0.12),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.vertical_align_bottom,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Primary Subtitle Position',
                                            style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Adjust vertical position: ${videoPlayerState._primarySubtitleVerticalPosition.round()}px',
                                            style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                              color: mutedColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                  // Adjustment buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Down button
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._primarySubtitleVerticalPosition - 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setPrimarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._primarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_down, size: 18),
                                      ),
                                      // Position display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${videoPlayerState._primarySubtitleVerticalPosition.round()}px',
                                          style: TextStyle(
                                            color: onSurfaceColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Up button
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._primarySubtitleVerticalPosition + 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setPrimarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._primarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_up, size: 18),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Secondary subtitle position adjustment (only show if secondary subtitles are loaded)
                      if (videoPlayerState._currentSecondarySubtitles.isNotEmpty)
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setSheetState) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? onSurfaceColor.withValues(alpha: 0.05) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: onSurfaceColor.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.vertical_align_top,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Secondary Subtitle Position',
                                              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Adjust vertical position: ${videoPlayerState._secondarySubtitleVerticalPosition.round()}px',
                                              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                                color: mutedColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Adjustment buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Down button (moves up due to swapped functionality)
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._secondarySubtitleVerticalPosition + 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setSecondarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._secondarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_down, size: 18),
                                      ),
                                      // Position display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: surfaceColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: onSurfaceColor.withValues(alpha: 0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${videoPlayerState._secondarySubtitleVerticalPosition.round()}px',
                                          style: TextStyle(
                                            color: onSurfaceColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Up button (moves down due to swapped functionality)
                                      ElevatedButton(
                                        onPressed: () async {
                                          final newPosition = (videoPlayerState._secondarySubtitleVerticalPosition - 10).clamp(-1000.0, 1000.0);
                                          await PreferencesModel.setSecondarySubtitleVerticalPosition(newPosition);
                                          videoPlayerState.setState(() {
                                            videoPlayerState._secondarySubtitleVerticalPosition = newPosition;
                                          });
                                          setSheetState(() {}); // Update the sheet UI
                                          videoPlayerState._updateActiveSubtitles(videoPlayerState.getCurrentPosition());
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: Icon(Icons.keyboard_arrow_up, size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Fullscreen button
