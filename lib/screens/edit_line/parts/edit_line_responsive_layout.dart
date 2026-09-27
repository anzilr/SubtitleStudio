part of '../../screen_edit_line.dart';

extension _EditLineResponsiveLayout on EditSubtitleScreenState {
  Widget _buildResponsiveContent(bool shouldShowVideo, Column originalContent) {
    if (ResponsiveLayout.shouldUseDesktopLayout(context)) {
      // Don't build the ResizableSplitView until the resize ratio is loaded
      if (!_isResizeRatioLoaded) {
        logInfo(
          'Waiting for resize ratio to load...',
          context: 'EditSubtitleScreen._buildResponsiveContent',
        );
        // Return a temporary layout while loading
        return Row(
          children: [
            Expanded(
              flex: 35, // Default 35% while loading
              child: _buildContentWithoutVideo(originalContent),
            ),
            Expanded(
              flex: 65, // Default 65% while loading
              child:
                  shouldShowVideo && _selectedVideoPath != null
                      ? Container(
                        margin: const EdgeInsets.all(16),
                        child: VideoPlayerWidget(
                          key: _videoPlayerKey,
                          videoPath: _selectedVideoPath!,
                          subtitleCollectionId: widget.subtitleId,
                          subtitles: _subtitles,
                          secondarySubtitles:
                              _showSecondarySubtitles
                                  ? _secondarySubtitlesForPlayer
                                  : [],
                          onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                            // Update comment in database and refresh UI
                            try {
                              await updateSubtitleLineComment(widget.subtitleId, subtitleIndex, comment);
                              // Refresh the subtitle data from database
                              _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;
                              
                              // Update current line if it matches
                              if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
                                setState(() {
                                  _subtitleLine!.comment = comment;
                                });
                              }
                              
                              // Regenerate subtitles for video player
                              _markSubtitlesForRegeneration();
                              _generateSubtitles();
                              
                              SnackbarHelper.showSuccess(context, 
                                comment != null ? 'Comment updated' : 'Comment deleted');
                            } catch (e) {
                              SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                            }
                          },
                        ),
                      )
                      : Container(),
            ),
          ],
        );
      }

      // Only log ratio changes when they're significant to reduce debug noise
      if (_lastLoggedRatio == null ||
          (_resizeRatio - _lastLoggedRatio!).abs() > 0.01) {
        logInfo(
          'Creating ResizableSplitView with initialRatio: $_resizeRatio, loaded: $_isResizeRatioLoaded',
          context: 'EditSubtitleScreen._buildResponsiveContent',
        );
        _lastLoggedRatio = _resizeRatio;
      }

      // Desktop layout: resizable editing interface and video player side by side
      // Apply layout switching based on preference (layout1/layout2)
      final videoContent = shouldShowVideo && _selectedVideoPath != null
          ? _buildVideoPlayerWidget()
          : NoVideoPlaceholder(onLoadVideo: _pickVideoFile);

      final editingContent = _buildContentWithoutVideo(originalContent);

      // Determine left and right children based on layout preference
      final leftChild = _layoutPreference == 'layout2' ? videoContent : editingContent;
      final rightChild = _layoutPreference == 'layout2' ? editingContent : videoContent;

      return ResizableSplitView(
        initialRatio: _resizeRatio,
        minRatio: 0.2,
        maxRatio: 0.8,
        dividerThickness: 6.0, // Increased from default 4.0 for better touch interaction
        onRatioChanged: (ratio) {
          // Only log every 10th ratio change to reduce noise
          if ((ratio * 1000).round() % 10 == 0) {
            logInfo(
              'ResizableSplitView onRatioChanged: $ratio',
              context: 'EditSubtitleScreen._buildResponsiveContent',
            );
          }
          _saveResizeRatio(ratio);
        },
        leftChild: leftChild,
        rightChild: rightChild,
      );
    } else {
      // Mobile layout: vertical layout with resizable video
      // Don't build until mobile resize ratio is loaded
      if (!_isMobileResizeRatioLoaded) {
        logInfo(
          'Waiting for mobile resize ratio to load...',
          context: 'EditSubtitleScreen.build',
        );
        // Return a temporary layout while loading
        return originalContent;
      }

      // Removed excessive logging that was causing performance issues during keyboard animations
      // logInfo(
      //   'Creating mobile ResizableSplitView with mobileRatio: $_mobileVideoResizeRatio, loaded: $_isMobileResizeRatioLoaded',
      //   context: 'EditSubtitleScreen.build',
      // );

      // Mobile layout with vertical ResizableSplitView - only if auto-resize is enabled and video is visible
      return ResponsiveLayout.shouldUseMobileLayout(context) && _autoResizeOnKeyboard && shouldShowVideo
        ? ResizableSplitView(
            initialRatio: _mobileVideoResizeRatio,
            minRatio: 0.2,
            maxRatio: 0.8,
            vertical: true, // Vertical split for mobile
            dividerThickness: 6.0, // Increased for mobile touch interaction
            onRatioChanged: (ratio) {
              logInfo(
                'Mobile ResizableSplitView onRatioChanged: $ratio',
                context: 'EditSubtitleScreen.build',
              );
              // Only save the ratio, don't trigger setState to avoid build loops
              _mobileVideoResizeRatio = ratio;
              _saveMobileResizeRatio(ratio);
            },
            leftChild: shouldShowVideo && _selectedVideoPath != null
              ? LayoutBuilder(
                  key: const Key('video_player_layout_builder'),
                  builder: (context, constraints) {
                    return VideoPlayerWidget(
                      key: _videoPlayerKey,
                      videoPath: _selectedVideoPath!,
                      subtitleCollectionId: widget.subtitleId,
                      subtitles: _subtitles,
                      secondarySubtitles: _showSecondarySubtitles ? _secondarySubtitlesForPlayer : [],
                      onSubtitlesUpdated: () {
                        // Debounce subtitle updates to prevent excessive rebuilds
                        _subtitleUpdateTimer?.cancel();
                        _subtitleUpdateTimer = Timer(const Duration(milliseconds: 100), () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _markSubtitlesForRegeneration();
                                _generateSubtitles();
                              });
                            }
                          });
                        });
                      },
                      onSubtitleMarked: (subtitleIndex, isMarked) async {
                        await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
                      },
                      onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                        // Update comment in database and refresh UI
                        try {
                          await updateSubtitleLineComment(widget.subtitleId, subtitleIndex, comment);
                          // Refresh the subtitle data from database
                          _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;
                          
                          // Update current line if it matches
                          if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
                            setState(() {
                              _subtitleLine!.comment = comment;
                            });
                          }
                          
                          // Regenerate subtitles for video player
                          _markSubtitlesForRegeneration();
                          _generateSubtitles();
                          
                          SnackbarHelper.showSuccess(context, 
                            comment != null ? 'Comment updated' : 'Comment deleted');
                        } catch (e) {
                          SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                        }
                      },
                      onPlayStateChanged: (isPlaying) {
                        // Only update if the state actually changed to avoid unnecessary rebuilds
                        if (mounted && _isVideoPlaying != isPlaying) {
                          setState(() {
                            _isVideoPlaying = isPlaying;
                          });
                        }
                      },
                      onRepeatModeToggled: (isEnabled) {
                        if (isEnabled != _isRepeatModeEnabled) {
                          _toggleRepeatMode();
                        }
                      },
                      isRepeatModeEnabled: _isRepeatModeEnabled,
                    );
                  },
                )
              : Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_outlined,
                          size: 60,
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No video loaded',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickVideoFile,
                          icon: const Icon(Icons.video_file),
                          label: const Text('Load Video'),
                        ),
                      ],
                    ),
                  ),
                ),
            rightChild: _buildContentWithoutVideo(originalContent),
          )
        : // Fallback to original content for mobile when auto-resize is disabled or no video is visible
          ResponsiveLayout.shouldUseMobileLayout(context) && !shouldShowVideo
            ? _buildContentWithoutVideo(originalContent) // Show mobile layout without video section
            : originalContent; // Original content with video section (for desktop or when video is visible)
    }
  }
}
