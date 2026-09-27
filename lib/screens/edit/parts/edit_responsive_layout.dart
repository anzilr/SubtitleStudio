part of '../../screen_edit.dart';

extension _EditResponsiveLayout on _EditScreenState {
  Widget _buildResponsiveContent(List<SubtitleLine> subtitleLines) {
    if (ResponsiveLayout.shouldUseDesktopLayout(context)) {
      // Don't build the ResizableSplitView until the resize ratio is loaded
      if (!_isResizeRatioLoaded) {
        print('DEBUG: EditScreen - Waiting for resize ratio to load...');
        // Return a temporary layout while loading
        return Row(
          children: [
            Expanded(
              flex: 35, // Default 35% while loading
              child: Column(
                children: [
                  // Title bar for subtitle list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subtitles,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${subtitleLines.length} Subtitles',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Subtitle list
                  Expanded(
                    child: riverpod.Consumer(
                    builder: (context, ref, _) {
                      final reactiveSubtitleLines = ref.watch(
                        editControllerProvider.select(
                          (state) => state.subtitleLines,
                        ),
                      );
                      return Stack(
                        children: [
                          ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              bottom: 16, 
                              top: 8,
                              left: 8,
                              right: 8,
                            ),
                            itemCount: reactiveSubtitleLines.length,
                            itemBuilder: (context, index) {
                              final line = reactiveSubtitleLines[index];
                              final textContent = line.edited ?? line.original;
                              return _buildSubtitleCard(line, index, textContent);
                            },
                          ),
                          _buildCustomScrollbar(),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 65, // Default 65% while loading
              child: Column(
                children: [
                  if (_isVideoVisible && _selectedVideoPath != null) ...[
                    // Video player takes most of the available space
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        child: VideoPlayerWidget(
                          key: _videoPlayerKey,
                          videoPath: _selectedVideoPath!,
                          subtitleCollectionId: widget.subtitleCollectionId,
                          subtitles: _subtitles,
                          secondarySubtitles: _secondarySubtitles,
                          onPositionChanged: _onVideoPositionChanged,
                          // onActiveSubtitleChanged: null, // Temporarily disable to test if this is causing interference
                          onActiveSubtitleChanged: (arrayIndex) {
                            debugPrint('onActiveSubtitleChanged called with arrayIndex: $arrayIndex, current _highlightedIndex: $_highlightedIndex');
                            debugPrint('onActiveSubtitleChanged: Stack trace:');
                            debugPrint(StackTrace.current.toString().split('\n').take(5).join('\n'));
                            
                            if (arrayIndex >= 0 && arrayIndex < subtitleLines.length) {
                              if (_highlightedIndex != arrayIndex) {
                                debugPrint('Updating highlighted index from $_highlightedIndex to $arrayIndex via video player callback');
                                _onSubtitleChange(arrayIndex);
                              } else {
                                debugPrint('Highlighted index already matches, skipping update to prevent redundant state change');
                              }
                            }
                          },
                          onSubtitlesUpdated: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                // Refresh subtitle lines from database to get latest changes
                                _refreshSubtitleLines();
                              }
                            });
                          },
                          onFullscreenExited: () {
                            // Refresh subtitle list when returning from fullscreen mode
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _refreshSubtitleLines();
                              }
                            });
                          },
                          onSubtitleMarked: (subtitleIndex, isMarked) async {
                            await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
                          },
                          onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                            // Update comment in database and refresh UI
                            debugPrint('SCREEN_EDIT COMMENT DEBUG:');
                            debugPrint('  - Received subtitleIndex: $subtitleIndex');
                            debugPrint('  - Comment: "$comment"');
                            debugPrint('  - Total subtitleLines.length: ${subtitleLines.length}');
                            debugPrint('  - Index within bounds: ${subtitleIndex < subtitleLines.length}');
                            
                            if (subtitleIndex < subtitleLines.length) {
                              debugPrint('  - SubtitleLine at index $subtitleIndex: "${subtitleLines[subtitleIndex].original.substring(0, subtitleLines[subtitleIndex].original.length.clamp(0, 30))}..."');
                            }
                            
                            try {
                              debugPrint('  - Calling database updateSubtitleLineComment with:');
                              debugPrint('    - subtitleCollectionId: ${widget.subtitleCollectionId}');
                              debugPrint('    - lineIndex: $subtitleIndex');
                              debugPrint('    - comment: "$comment"');
                              
                              final success = await _controller.updateComment(subtitleIndex, comment);
        if (!success) throw StateError('Comment update failed');
                              debugPrint('  - Database update successful');
                              
                              // Refresh the subtitle line in UI
                              if (subtitleIndex < subtitleLines.length) {
                                _setEditorState(() {
                                  subtitleLines[subtitleIndex].comment = comment;
                                });
                                // Update controller
                                _controller.updateSubtitleLineLocally(subtitleIndex, subtitleLines[subtitleIndex]);
                                
                                // Regenerate subtitles for video player
                                _subtitles = _generateSubtitles(subtitleLines);
                                
                                // Update video player with new subtitles
                                if (_videoPlayerKey.currentState != null) {
                                  _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
                                }
                              }
                              
                              SnackbarHelper.showSuccess(context, 
                                comment != null ? 'Comment updated' : 'Comment deleted');
                            } catch (e) {
                              debugPrint('  - Error: $e');
                              SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                            }
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    // Placeholder when no video is loaded
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 80,
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                  ],
                ],
              ),
            ),
          ],
        );
      }
      
      // Desktop layout: resizable sidebar + video player side by side
      // Swap leftChild and rightChild based on layout preference
      final leftChild = _isLayout1
          ? _buildSubtitleListInterface(subtitleLines)
          : _buildVideoPlayerInterface(subtitleLines);
      
      final rightChild = _isLayout1
          ? _buildVideoPlayerInterface(subtitleLines)
          : _buildSubtitleListInterface(subtitleLines);

      return ResizableSplitView(
        initialRatio: _resizeRatio,
        minRatio: 0.2,
        maxRatio: 0.8,
        dividerThickness: 6.0, // Increased from default 4.0 for better touch interaction
        onRatioChanged: (ratio) {
          _saveResizeRatio(ratio);
        },
        leftChild: leftChild,
        rightChild: rightChild,
      );
    } else {
      // Mobile layout: vertical layout with resizable video
      // Don't build until both resize ratios are loaded
      if (!_isMobileResizeRatioLoaded) {
        if (kDebugMode) {
          print('DEBUG: EditScreen - Waiting for mobile resize ratio to load...');
        }
        // Return a temporary layout while loading
        return Column(
          children: [
            if (_isVideoVisible && _selectedVideoPath != null)
              SizedBox(
                height: 250, // Default height while loading
                child: VideoPlayerWidget(
                  key: _videoPlayerKey,
                  videoPath: _selectedVideoPath!,
                  subtitleCollectionId: widget.subtitleCollectionId,
                  subtitles: _subtitles,
                  secondarySubtitles: _secondarySubtitles,
                  onPositionChanged: _onVideoPositionChanged,
                  onActiveSubtitleChanged: (arrayIndex) {
                    if (arrayIndex >= 0 && arrayIndex < subtitleLines.length) {
                      _onSubtitleChange(arrayIndex);
                    }
                  },
                  onSubtitlesUpdated: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _refreshSubtitleLines();
                      }
                    });
                  },
                  onFullscreenExited: () {
                    // Refresh subtitle list when returning from fullscreen mode
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _refreshSubtitleLines();
                      }
                    });
                  },
                  onSubtitleMarked: (subtitleIndex, isMarked) async {
                    await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
                  },
                  onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                    // Update comment in database and refresh UI
                    try {
                      final success = await _controller.updateComment(subtitleIndex, comment);
        if (!success) throw StateError('Comment update failed');
                      // Refresh the subtitle line in UI
                      if (subtitleIndex < subtitleLines.length) {
                        _setEditorState(() {
                          subtitleLines[subtitleIndex].comment = comment;
                        });
                        // Update controller
                        _controller.updateSubtitleLineLocally(subtitleIndex, subtitleLines[subtitleIndex]);
                        
                        // Regenerate subtitles for video player
                        _subtitles = _generateSubtitles(subtitleLines);
                        
                        // Update video player with new subtitles
                        if (_videoPlayerKey.currentState != null) {
                          _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
                        }
                      }
                      
                      SnackbarHelper.showSuccess(context, 
                        comment != null ? 'Comment updated' : 'Comment deleted');
                    } catch (e) {
                      SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                    }
                  },
                ),
              ),
            if (_isVideoVisible && _selectedVideoPath != null)
              const SizedBox(height: 16),
            Expanded(
              child: riverpod.Consumer(
                    builder: (context, ref, _) {
                      final reactiveSubtitleLines = ref.watch(
                        editControllerProvider.select(
                          (state) => state.subtitleLines,
                        ),
                      );
                      return Stack(
                  children: [
                    ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 16, 
                        top: 16
                      ),
                      itemCount: reactiveSubtitleLines.length,
                      itemBuilder: (context, index) {
                        final line = reactiveSubtitleLines[index];
                        final textContent = line.edited ?? line.original;
                        return _buildSubtitleCard(line, index, textContent);
                      },
                    ),
                    _buildCustomScrollbar(),
                  ],
                );
              }),
            ),
          ],
        );
      }

      // Mobile layout with vertical ResizableSplitView - only if video is loaded and visible
      return ResponsiveLayout.shouldUseMobileResize(context) && _isVideoLoaded && _isVideoVisible
        ? ResizableSplitView(
            initialRatio: _mobileVideoResizeRatio,
            minRatio: 0.2,
            maxRatio: 0.8,
            vertical: true, // Vertical split for mobile
            dividerThickness: 6.0, // Increased for mobile touch interaction
            onRatioChanged: (ratio) {
              // Use post frame callback to avoid "Build scheduled during frame" error
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _setEditorState(() {
                    _mobileVideoResizeRatio = ratio;
                  });
                }
              });
              _saveMobileResizeRatio(ratio);
            },
            leftChild: _isVideoVisible && _selectedVideoPath != null
              ? Column(
                  children: [
                    // Video player
                    Expanded(
                      child: VideoPlayerWidget(
                        key: _videoPlayerKey,
                        videoPath: _selectedVideoPath!,
                        subtitleCollectionId: widget.subtitleCollectionId,
                        subtitles: _subtitles,
                        secondarySubtitles: _secondarySubtitles,
                        onPositionChanged: _onVideoPositionChanged,
                        onActiveSubtitleChanged: (arrayIndex) {
                          if (arrayIndex >= 0 && arrayIndex < subtitleLines.length) {
                            _onSubtitleChange(arrayIndex);
                          }
                        },
                        onSubtitlesUpdated: () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _refreshSubtitleLines();
                            }
                          });
                        },
                        onFullscreenExited: () {
                          // Refresh subtitle list when returning from fullscreen mode
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _refreshSubtitleLines();
                            }
                          });
                        },
                        onSubtitleMarked: (subtitleIndex, isMarked) async {
                          await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
                        },
                        onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                          // Update comment in database and refresh UI
                          try {
                            final success = await _controller.updateComment(subtitleIndex, comment);
        if (!success) throw StateError('Comment update failed');
                            // Refresh the subtitle line in UI
                            if (subtitleIndex < subtitleLines.length) {
                              _setEditorState(() {
                                subtitleLines[subtitleIndex].comment = comment;
                              });
                              // Update controller
                              _controller.updateSubtitleLineLocally(subtitleIndex, subtitleLines[subtitleIndex]);
                              
                              // Regenerate subtitles for video player
                              _subtitles = _generateSubtitles(subtitleLines);
                              
                              // Update video player with new subtitles
                              if (_videoPlayerKey.currentState != null) {
                                _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
                              }
                            }
                            
                            SnackbarHelper.showSuccess(context, 
                              comment != null ? 'Comment updated' : 'Comment deleted');
                          } catch (e) {
                            SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                          }
                        },
                      ),
                    ),
                    // Waveform section (when visible)
                    if (_isWaveformVisible) ...[
                      const Divider(height: 1),
                      SizedBox(
                        height: Platform.isWindows || Platform.isMacOS || Platform.isLinux 
                            ? 240.0 
                            : 180.0, // Taller on desktop for better visibility
                        child: WaveformWidget(
                            key: _waveformKey,
                            subtitles: subtitleLines,
                            playbackPosition: _lastVideoPosition,
                            subtitleCollectionId: widget.subtitleCollectionId,
                            sessionId: widget.sessionId,
                            highlightedSubtitleIndex: _highlightedIndex,
                            onSeek: (Duration position) {
                              // Seek video to the selected position
                              if (_videoPlayerKey.currentState != null) {
                                _videoPlayerKey.currentState!.seekTo(position);
                              }
                            },
                            onSubtitleHighlight: (int index) {
                              // Scroll to and highlight the subtitle in the list
                              _scrollToIndexWithLoading(index);
                              _setEditorState(() {
                                _highlightedIndex = index;
                              });
                            },
                            onSubtitlesUpdated: () async {
                              // Refresh subtitle lines from database
                              await _refreshSubtitleLines();
                            },
                            onAddLineConfirmed: (Duration startTime, Duration endTime) {
                              // Open add line sheet with selected times
                              _openAddLineSheetWithTimes(startTime, endTime);
                            },
                          ),
                      ),
                    ],
                  ],
                )
              : Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 60,
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                    ],
                  ),
                ),
            rightChild: riverpod.Consumer(
                    builder: (context, ref, _) {
                      final reactiveSubtitleLines = ref.watch(
                        editControllerProvider.select(
                          (state) => state.subtitleLines,
                        ),
                      );
                      return Stack(
                children: [
                  ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16, 
                      top: 16
                    ),
                    itemCount: reactiveSubtitleLines.length,
                    itemBuilder: (context, index) {
                      final line = reactiveSubtitleLines[index];
                      final textContent = line.edited ?? line.original;
                      return _buildSubtitleCard(line, index, textContent);
                    },
                  ),
                  _buildCustomScrollbar(),
                ],
              );
            }),
          )
        : // Fallback to original mobile layout for very small screens or when no video is loaded
          Column(
            children: [
              if (_isVideoVisible && _selectedVideoPath != null && _isVideoLoaded)
                SizedBox(
                  height: ResponsiveLayout.getMobileVideoHeight(
                    context, 
                    _mobileVideoResizeRatio,
                    includeWaveformHeight: false, // Don't include waveform in video height
                  ),
                  child: VideoPlayerWidget(
                    key: _videoPlayerKey,
                    videoPath: _selectedVideoPath!,
                    subtitleCollectionId: widget.subtitleCollectionId,
                    subtitles: _subtitles,
                    secondarySubtitles: _secondarySubtitles,
                    onPositionChanged: _onVideoPositionChanged,
                    onActiveSubtitleChanged: (arrayIndex) {
                      if (arrayIndex >= 0 && arrayIndex < subtitleLines.length) {
                        _onSubtitleChange(arrayIndex);
                      }
                    },
                    onSubtitlesUpdated: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _refreshSubtitleLines();
                        }
                      });
                    },
                    onFullscreenExited: () {
                      // Refresh subtitle list when returning from fullscreen mode
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _refreshSubtitleLines();
                        }
                      });
                    },
                    onSubtitleMarked: (subtitleIndex, isMarked) async {
                      await _handleVideoPlayerMarkToggle(subtitleIndex, isMarked);
                    },
                    onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                      // Update comment in database and refresh UI
                      try {
                        final success = await _controller.updateComment(subtitleIndex, comment);
        if (!success) throw StateError('Comment update failed');
                        // Refresh the subtitle line in UI
                        if (subtitleIndex < subtitleLines.length) {
                          _setEditorState(() {
                            subtitleLines[subtitleIndex].comment = comment;
                          });
                          // Update controller
                          _controller.updateSubtitleLineLocally(subtitleIndex, subtitleLines[subtitleIndex]);
                          
                          // Regenerate subtitles for video player
                          _subtitles = _generateSubtitles(subtitleLines);
                          
                          // Update video player with new subtitles
                          if (_videoPlayerKey.currentState != null) {
                            _videoPlayerKey.currentState!.updateSubtitles(_subtitles);
                          }
                        }
                        
                        SnackbarHelper.showSuccess(context, 
                          comment != null ? 'Comment updated' : 'Comment deleted');
                      } catch (e) {
                        SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
                      }
                    },
                  ),
                ),
              // Waveform section for mobile layout (when visible)
              if (_isVideoVisible && _selectedVideoPath != null && _isVideoLoaded && _isWaveformVisible) ...[
                const Divider(height: 1),
                SizedBox(
                  height: 180.0,
                  child: WaveformWidget(
                      key: _waveformKey,
                      subtitles: subtitleLines,
                      playbackPosition: _lastVideoPosition,
                      subtitleCollectionId: widget.subtitleCollectionId,
                      sessionId: widget.sessionId,
                      highlightedSubtitleIndex: _highlightedIndex,
                      onSeek: (Duration position) {
                        // Seek video to the selected position
                        if (_videoPlayerKey.currentState != null) {
                          _videoPlayerKey.currentState!.seekTo(position);
                        }
                      },
                      onSubtitleHighlight: (int index) {
                        // Scroll to and highlight the subtitle in the list
                        _scrollToIndexWithLoading(index);
                        _setEditorState(() {
                          _highlightedIndex = index;
                        });
                      },
                      onSubtitlesUpdated: () async {
                        // Refresh subtitle lines from database
                        await _refreshSubtitleLines();
                      },
                      onAddLineConfirmed: (Duration startTime, Duration endTime) {
                        // Open add line sheet with selected times
                        _openAddLineSheetWithTimes(startTime, endTime);
                      },
                    ),
                ),
              ],
              if (_isVideoVisible && _selectedVideoPath != null && _isVideoLoaded)
                const SizedBox(height: 16),
              Expanded(
                child: riverpod.Consumer(
                    builder: (context, ref, _) {
                      final reactiveSubtitleLines = ref.watch(
                        editControllerProvider.select(
                          (state) => state.subtitleLines,
                        ),
                      );
                      return Stack(
                    children: [
                      ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom + 16, 
                          top: 16
                        ),
                        itemCount: reactiveSubtitleLines.length,
                        itemBuilder: (context, index) {
                          final line = reactiveSubtitleLines[index];
                          final textContent = line.edited ?? line.original;
                          return _buildSubtitleCard(line, index, textContent);
                        },
                      ),
                      _buildCustomScrollbar(),
                    ],
                  );
                }),
              ),
            ],
          );
    }
  }
}
