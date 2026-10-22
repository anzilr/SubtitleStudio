part of '../../screen_edit_line.dart';

extension _EditLineLayout on EditSubtitleScreenState {
  Widget _buildEditLineLayout(
    BuildContext context,
    bool shouldShowVideo,
  ) {
      final portraitMetrics = EditLinePortraitMetrics.of(context);
      return FirstTimeInstructions(
        screenName: 'edit_line',
        instructions: editLineInstructions,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            // Check for unsaved changes
            if (_hasUnsavedChanges()) {
              await _showUnsavedChangesDialog();
            } else {
              // Return the current active index (convert from 1-based to 0-based)
              final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
              Navigator.of(context).pop(currentIndex);
            }
          },
          child: Builder(
            builder: (context) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      // Check for unsaved changes
                      if (_hasUnsavedChanges()) {
                        await _showUnsavedChangesDialog();
                        // Note: _showUnsavedChangesDialog handles navigation internally
                      } else {
                        // Return the current active index (convert from 1-based to 0-based)
                        final currentIndex = _subtitleLine != null ? _subtitleLine!.index - 1 : widget.index;
                        Navigator.of(context).pop(currentIndex);
                      }
                    },
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child:
                            _subtitle != null
                                ? ScrollingTitleWidget(
                                  title: _subtitle!.fileName,
                                  style: TextStyle(
                                    color: Theme.of(context).appBarTheme.foregroundColor,
                                    fontSize: 16,
                                  ),
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.4,
                                )
                                : Text(
                                  "Subtitle Studio",
                                  style: TextStyle(
                                    color: Theme.of(context).appBarTheme.foregroundColor,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                      // Mark indicator for current subtitle line
                      if (_subtitleLine?.marked == true)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: Listener(
                            onPointerDown: (PointerDownEvent event) {
                              // Handle right-click on desktop platforms
                              if (event.kind == PointerDeviceKind.mouse && 
                                  event.buttons == kSecondaryMouseButton) {
                                _showCommentDialogForCurrentLine();
                              }
                            },
                            child: GestureDetector(
                              onLongPress: () {
                                // Handle long press on touch devices
                                _showCommentDialogForCurrentLine();
                              },
                              onTap: () {
                                // Optional: quick toggle mark status on tap
                                _toggleMarkLine();
                              },
                              child: Icon(
                                Icons.bookmark_added,
                                color: Theme.of(context).appBarTheme.foregroundColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    const ThemeSwitcherButton(),
                    if (_isVideoLoaded)
                      IconButton(
                        onPressed: () {
                          _setEditLineState(() {
                            _isVideoVisible = !_isVideoVisible;
                          });

                          if (!_isVideoVisible) {
                            // The user hid the player. Reject previously
                            // scheduled readiness waits and stale seeks.
                            _mediaRequests.invalidateMedia();
                          } else if (_subtitleLine != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _isVideoVisible && _isVideoLoaded) {
                                _seekVideoToSubtitle();
                              }
                            });
                          }
                        },
                        icon:
                            _isVideoVisible
                                ? SvgPicture.asset(
                                  'assets/movie_off.svg',
                                  semanticsLabel: 'Movie off',
                                  height: 25,
                                  width: 35,
                                )
                                : const Icon(Icons.movie_outlined),
                      ),
                    if (_isVideoLoaded && _isVideoVisible)
                      IconButton(
                        tooltip: 'Sync with video position',
                        icon: const Icon(Icons.sync),
                        onPressed: _syncWithVideoPosition,
                      ),
                    IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () => _showEditLineMenuModal(),
                    ),
                  ],
                ),
                body:
                    _subtitle?.lines.isEmpty ?? false
                        ? EmptySubtitleView(onAddSubtitle: _addInitialSubtitleLine)
                        : GestureDetector(
                          onSecondaryTap:
                              () =>
                                  _showEditLineMenuModal(), // Right-click opens menu
                          child: _buildResponsiveContent(
                            shouldShowVideo,
                            Column(
                              children: [
                                // Video player at the top
                                if (shouldShowVideo)
                                  SizedBox(
                                    height: portraitMetrics.videoHeight,
                                    child: VideoPlayerWidget(
                                      key: _videoPlayerKey,
                                      videoPath: _selectedVideoPath!,
                                      subtitleCollectionId: widget.subtitleId,
                                      subtitles: _subtitles,
                                      secondarySubtitles:
                                          _showSecondarySubtitles
                                              ? _secondarySubtitlesForPlayer
                                              : [],
                                      onSubtitlesUpdated: () {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (mounted) {
                                                _setEditLineState(() {
                                                  _markSubtitlesForRegeneration();
                                                  _generateSubtitles();
                                                });
                                              }
                                            });
                                      },
                                      onSubtitleMarked: (
                                        subtitleIndex,
                                        isMarked,
                                      ) async {
                                        // Handle marking/unmarking from video player
                                        await _handleVideoPlayerMarkToggle(
                                          subtitleIndex,
                                          isMarked,
                                        );
                                      },
                                      onSubtitleCommentUpdated: (subtitleIndex, comment) async {
                                        // Update comment in database and refresh UI
                                        try {
                                          await _editLineController.updateLineComment(subtitleIndex, comment);
                                          // Refresh the subtitle data from database
                                          _subtitle = (await _editLineController.loadSubtitleCollection())!;
                                          
                                          // Update current line if it matches
                                          if (_subtitleLine != null && _subtitleLine!.index == subtitleIndex + 1) {
                                            _setEditLineState(() {
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
                                        // Update play/pause button state when video player state changes
                                        if (mounted) {
                                          _setEditLineState(() {
                                            _isVideoPlaying = isPlaying;
                                          });
                                        }
                                      },
                                      onRepeatModeToggled: (isEnabled) {
                                        // Handle repeat mode toggle from video player
                                        if (isEnabled != _isRepeatModeEnabled) {
                                          _toggleRepeatMode();
                                        }
                                      },
                                      isRepeatModeEnabled: _isRepeatModeEnabled,
                                    ),
                                  ),
                                // Add spacing after video when it's shown
                                if (shouldShowVideo) const SizedBox(height: 1),
                                // Main content in scrollable area
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.all(portraitMetrics.contentPadding),
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // In edit mode, skip the original text field and related controls
                                          if (!_isEditMode) ..._buildOriginalTextSection(context),

                                          // Empty space where the labels and line count used to be
                                          const SizedBox(height: 0),
                                          const SizedBox(height: 5),
                                          _buildEditedTextStack(context),
                                          const SizedBox(height: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              LayoutBuilder(
                                                builder: (context, constraints) {
                                                  // Calculate available width and adjust button sizes accordingly
                                                  double availableWidth =
                                                      constraints.maxWidth;
                                                  double buttonSize =
                                                      availableWidth < 400
                                                          ? 28
                                                          : 32; // Smaller icons for narrow screens
                                                  double buttonPadding =
                                                      availableWidth < 400
                                                          ? 0.4
                                                          : 1.0; // Less padding for narrow screens

                                                  return Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Flexible(
                                                        child: IconButton(
                                                          constraints:
                                                              BoxConstraints(
                                                                minWidth: 24,
                                                                maxWidth: 36,
                                                              ),
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    buttonPadding,
                                                              ),
                                                          onPressed:
                                                              _subtitleLine !=
                                                                      null
                                                                  ? () => _prevSubtitle(
                                                                    widget
                                                                        .subtitleId,
                                                                    _subtitleLine!
                                                                            .index -
                                                                        1,
                                                                  )
                                                                  : null,
                                                          icon: Icon(
                                                            Icons.skip_previous,
                                                            size: buttonSize,
                                                            color:
                                                                StudioDesignTokens.of(context).primaryAction,
                                                          ),
                                                        ),
                                                      ),
                                                      // Dictionary popup menu button (moved here - always visible)
                                                      Flexible(
                                                        child: PopupMenuButton<
                                                          String
                                                        >(
                                                          icon: Icon(
                                                            Icons.book,
                                                            size: buttonSize,
                                                            color:
                                                                StudioDesignTokens.of(context).primaryAction,
                                                          ),
                                                          offset: const Offset(
                                                            0,
                                                            8,
                                                          ),
                                                          tooltip: 'Dictionary',
                                                          onSelected: (
                                                            String value,
                                                          ) {
                                                            if (value == "olam") {
                                                              _showOlamDictionary();
                                                            } else if (value ==
                                                                "urban") {
                                                              _showUrbanDictionary();
                                                            } else if (value ==
                                                                "msone") {
                                                              _showMsoneDictionary();
                                                            } else if (value ==
                                                                "ai_explain") {
                                                              _showAiExplanation();
                                                            }
                                                          },
                                                          itemBuilder:
                                                              (
                                                                BuildContext
                                                                context,
                                                              ) => [
                                                                // MSone Dictionary option (moved from icon row)
                                                                if (_isMsoneEnabled)
                                                                  PopupMenuItem(
                                                                    value:
                                                                        "msone",
                                                                    child: Container(
                                                                      padding:
                                                                          const EdgeInsets.symmetric(
                                                                            vertical:
                                                                                4,
                                                                          ),
                                                                      child: Row(
                                                                        children: [
                                                                          SvgPicture.asset(
                                                                            'assets/msone.svg',
                                                                            semanticsLabel:
                                                                                'Msone Logo',
                                                                            height:
                                                                                20,
                                                                            width:
                                                                                20,
                                                                            colorFilter: ColorFilter.mode(
                                                                               StudioDesignTokens.of(context).primaryAction,
                                                                               BlendMode.srcIn,
                                                                             ),
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                16,
                                                                          ),
                                                                          Text(
                                                                            "MSone Dictionary",
                                                                            style: Theme.of(
                                                                              context,
                                                                            ).textTheme.bodyLarge?.copyWith(
                                                                              fontWeight:
                                                                                  FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                // Show Olam Dictionary only if MSone is enabled
                                                                if (_isMsoneEnabled)
                                                                  PopupMenuItem(
                                                                    value: "olam",
                                                                    child: Container(
                                                                      padding:
                                                                          const EdgeInsets.symmetric(
                                                                            vertical:
                                                                                4,
                                                                          ),
                                                                      child: Row(
                                                                        children: [
                                                                          Icon(
                                                                            Icons
                                                                                .book,
                                                                            color: StudioDesignTokens.of(context).primaryAction, // Purple color for Olam
                                                                            size:
                                                                                24,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                16,
                                                                          ),
                                                                          Text(
                                                                            "Olam Dictionary",
                                                                            style: Theme.of(
                                                                              context,
                                                                            ).textTheme.bodyLarge?.copyWith(
                                                                              fontWeight:
                                                                                  FontWeight.w600,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                // Urban Dictionary is always available
                                                                PopupMenuItem(
                                                                  value: "urban",
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .forum,
                                                                          color: StudioDesignTokens.of(context).primaryAction, // Green color for Urban Dictionary
                                                                          size:
                                                                              24,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              16,
                                                                        ),
                                                                        Text(
                                                                          "Urban Dictionary",
                                                                          style: Theme.of(
                                                                            context,
                                                                          ).textTheme.bodyLarge?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                // AI Explanation
                                                                PopupMenuItem(
                                                                  value: "ai_explain",
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.symmetric(
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .auto_awesome,
                                                                          color: StudioDesignTokens.of(context).primaryAction, // Purple color for AI
                                                                          size:
                                                                              24,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              16,
                                                                        ),
                                                                        Text(
                                                                          "Explain with AI",
                                                                          style: Theme.of(
                                                                            context,
                                                                          ).textTheme.bodyLarge?.copyWith(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                        ),
                                                      ),
                                                      Flexible(
                                                        child: FormattingMenu(
                                                          controller:
                                                              _editedController,
                                                          colorHistory:
                                                              _colorHistory,
                                                          onColorHistoryUpdate:
                                                              _saveColorHistory,
                                                        ),
                                                      ),
                                                      if (_subtitleLine != null &&
                                                          _subtitle != null)
                                                        Flexible(
                                                          child: SubtitleActionsMenu(
                                                            editedController:
                                                                _editedController,
                                                            startTime:
                                                                _startTimeController
                                                                    .text,
                                                            endTime:
                                                                _endTimeController
                                                                    .text,
                                                            subtitleId:
                                                                widget.subtitleId,
                                                            currentLine:
                                                                _subtitleLine!,
                                                            collection:
                                                                _subtitle!,
                                                            refreshCallback:
                                                                () => _fetchSubtitleLine(
                                                                  widget
                                                                      .subtitleId,
                                                                  _subtitleLine!
                                                                      .index,
                                                                ),
                                                            refreshToLineCallback:
                                                                (newLineIndex) => _fetchSubtitleLine(
                                                                  widget
                                                                      .subtitleId,
                                                                  newLineIndex - 1, // Convert from 1-based to 0-based array index
                                                                ),
                                                            sessionId: widget.sessionId,
                                                            onBeforeAdd: _updateSubtitleSilently, // Save before adding new line
                                                            isVideoLoaded: _isVideoLoaded,
                                                            getCurrentVideoPosition: _isVideoLoaded && _videoPlayerKey.currentState != null
                                                                ? () => _videoPlayerKey.currentState!.getCurrentPosition()
                                                                : null,
                                                          ),
                                                        ),
                                                      Flexible(
                                                        child: IconButton(
                                                          constraints:
                                                              BoxConstraints(
                                                                minWidth: 24,
                                                                maxWidth: 36,
                                                              ),
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    buttonPadding,
                                                              ),
                                                          icon: Icon(
                                                            Icons.save,
                                                            size: buttonSize,
                                                            color:
                                                                StudioDesignTokens.of(context).primaryAction,
                                                          ),
                                                          onPressed: () async {
                                                            // Show loading state briefly for better UX
                                                            _setEditLineState(() {
                                                              // Could add a loading indicator here if needed
                                                            });

                                                            // Perform save operation asynchronously
                                                            await Future.microtask(
                                                              () async {
                                                                await _updateSubtitle(
                                                                  context,
                                                                );
                                                              },
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      // Play/Pause button for video
                                                      if (_isVideoLoaded)
                                                        Flexible(
                                                          child: IconButton(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      buttonPadding,
                                                                ),
                                                            constraints:
                                                                BoxConstraints(
                                                                  minWidth: 24,
                                                                  maxWidth: 36,
                                                                ),
                                                            icon: Icon(
                                                              _isVideoPlaying
                                                                  ? Icons.pause
                                                                  : Icons
                                                                      .play_arrow,
                                                              size: buttonSize,
                                                              color:
                                                                  StudioDesignTokens.of(context).primaryAction,
                                                            ),
                                                            onPressed: () {
                                                              if (_videoPlayerKey
                                                                      .currentState !=
                                                                  null) {
                                                                if (_isVideoPlaying) {
                                                                  _videoPlayerKey
                                                                      .currentState!
                                                                      .pause();
                                                                } else {
                                                                  _videoPlayerKey
                                                                      .currentState!
                                                                      .play();
                                                                }
                                                              }
                                                            },
                                                          ),
                                                        ),

                                                      Flexible(
                                                        child: IconButton(
                                                          constraints:
                                                              BoxConstraints(
                                                                minWidth: 24,
                                                                maxWidth: 36,
                                                              ),
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal:
                                                                    buttonPadding,
                                                              ),
                                                          onPressed:
                                                              _subtitleLine !=
                                                                      null
                                                                  ? () => _nextSubtitle(
                                                                    widget
                                                                        .subtitleId,
                                                                    _subtitleLine!
                                                                            .index +
                                                                        1,
                                                                  )
                                                                  : null,
                                                          icon: Icon(
                                                            Icons.skip_next,
                                                            size: buttonSize,
                                                            color:
                                                                StudioDesignTokens.of(context).primaryAction,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 0),

                                          // Time fields section - update keyboard type for both fields
                                          _buildEditLineTimeSection(),
                                          SizedBox(height: portraitMetrics.sectionGap),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ); // Scaffold
            }, // builder (inner Builder)
          ), // Builder (inner - wraps Scaffold)
        ), // PopScope
      ); // FirstTimeInstructions
  }
}
