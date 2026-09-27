part of '../../screen_edit.dart';

extension _EditMenuActions on _EditScreenState {
  void _showMainMenuModal() {
    final waveformState = ref.read(waveformControllerProvider);

    showEditMainMenu(
      context: context,
      isSourceView: _isSourceView,
      isVideoLoaded: _isVideoLoaded,
      floatingControlsEnabled: _floatingControlsEnabled,
      isWaveformLoaded: waveformState is WaveformReady,
      isWaveformVisible: _isWaveformVisible,
      hasSecondarySubtitles: _secondarySubtitles.isNotEmpty,
      showSecondarySubtitles: _showSecondarySubtitles,
      isMsoneEnabled: _isMsoneEnabled,
    ).then(_handleMainMenuSelection);
  }

  // Handle main menu selection
  void _handleMainMenuSelection(String? value) async {
    if (value == null) return;

    switch (value) {
      case 'switch_to_source':
        _switchToSourceView();
        break;
      case 'switch_to_timeline':
        await _switchToTimelineView();
        break;
      case 'load_video':
        if (_isVideoLoaded) {
          _unloadVideo();
        } else {
          _pickVideoFile();
        }
        break;
      case 'toggle_controls':
        _toggleFloatingControls(!_floatingControlsEnabled);
        break;
      case 'generate_waveform':
        _toggleWaveform();
        break;
      case 'regenerate_waveform':
        // Force regenerate waveform by clearing cache and reloading
        if (_selectedVideoPath != null) {
          await PreferencesModel.clearWaveformCache(widget.subtitleCollectionId);
          ref.read(waveformControllerProvider.notifier).dispatch(const ClearWaveform());
          _setEditorState(() {
            _isWaveformVisible = true;
          });
          ref.read(waveformControllerProvider.notifier).dispatch(LoadAudioFile(
            _selectedVideoPath!,
            subtitleCollectionId: widget.subtitleCollectionId,
          ));
        }
        break;
      case 'save':
        _handleSave();
        break;
      case 'save_project':
        _handleSaveProject();
        break;
      case 'save_file_as':
        _handleSaveFileAs();
        break;
      case 'project_settings':
        _showProjectSettings();
        break;
      case 'goto':
        _showGoToLineModal();
        break;
      case 'find_replace':
        _showFindReplaceModal();
        break;
      case 'marked_lines':
        _showMarkedLinesModal();
        break;
      case 'checkpoint_history':
        _showCheckpointHistoryModal();
        break;
      case 'import_comments':
        _showImportCommentsModal();
        break;
      case 'secondary_subtitle':
        _showSecondarySubtitleModal();
        break;
      case 'toggle_secondary':
        _toggleSecondarySubtitles(!_showSecondarySubtitles);
        break;
      case 'sync':
        _showSyncModal();
        break;
      case 'remove_hearing_impaired':
        _removeHearingImpairedLines();
        break;
      case 'banners':
        _showInsertBannersModal();
        break;
      case 'malayalam_normalize':
        _showMalayalamNormalizationModal();
        break;
      case 'submit_msone':
        _showSubmitToMsoneModal();
        break;
      case 'settings':
        _showSettingsModal();
        break;
      case 'help':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        );
        break;
    }
  }

  // Selection menu popup
  void _showSelectionMenuModal({Offset? position}) {
    showEditSelectionMenu(
      context: context,
      position: position,
    ).then(_handleSelectionMenuSelection);
  }

  // Handle selection menu selection
  void _handleSelectionMenuSelection(String? value) {
    if (value == null) return;

    switch (value) {
      case 'copy':
        _copySelectedSubtitles();
        break;
      case 'shift_times':
        _showShiftSelectedTimesDialog();
        break;
      case 'delete':
        _showBatchDeleteConfirmation();
        break;
      case 'select_by_index':
        _showSelectByIndexDialog();
        break;
      case 'range_selection':
        _toggleRangeSelectionMode();
        break;
    }
  }

  // Helper methods for menu actions
  void _showGoToLineModal() {
    showGotToLineModal(
      context: context,
      initialValue: '',
      hintText: subtitleLines.length,
      title: 'Go to line',
      onSubmitted: (value) async {
        final lineNumber = int.tryParse(value.trim());
        if (lineNumber == null ||
            lineNumber < 1 ||
            lineNumber > subtitleLines.length) {
          SnackbarHelper.showError(
            context,
            'Enter a line number between 1 and ${subtitleLines.length}',
          );
          return;
        }

        await _scrollToIndexWithLoading(lineNumber);
        _highlightIndex(lineNumber - 1);

        if (_isVideoLoaded) {
          _seekToSubtitle(lineNumber - 1);
        }
      },
    );
  }

  Future<void> _showFindReplaceModal() async {
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
        ),
        builder: (context) {
          return SearchReplaceSheet(
            subtitleLines: subtitleLines,
            subtitleId: widget.subtitleCollectionId,
            isReplaceMode: true,
            onRefresh: _refreshSubtitleLines,
            onLineSelected: (index) async {
              Navigator.pop(context);
              await _scrollToIndexWithLoading(index + 1); // Convert from 0-based to 1-based
              _highlightIndex(index); // Use 0-based for highlighting
            },
          );
        },
      );
    }
  }

  Future<void> _showSecondarySubtitleModal() async {
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
        ),
        builder: (context) {
            return SecondarySubtitleSheet(
              originalSubtitles: subtitleLines,
              subtitleCollectionId: widget.subtitleCollectionId,
              videoPlayerState: _videoPlayerKey.currentState,
              onSecondarySubtitlesLoaded: (secondarySubtitles) {
                _setEditorState(() {
                  _originalSecondarySubtitles = secondarySubtitles;
                  _secondarySubtitles = _generateSimpleSubtitles(secondarySubtitles);
                  if (_videoPlayerKey.currentState != null) {
                    _videoPlayerKey.currentState!.updateSecondarySubtitles(_secondarySubtitles);
                  }
                });
                SnackbarHelper.showSuccess(context, 'Secondary subtitles loaded');
              },
            );
        },
      );
    }
  }

    // Load saved secondary subtitle (external path or original flag)
    // baseSubtitles can be provided (the freshly fetched subtitles) to ensure original-text restoration uses the right data
    Future<void> _loadSavedSecondarySubtitle([List<SubtitleLine>? baseSubtitles]) async {
      // Riverpod migration - secondary subtitles already loaded by controller initialization
      // Just sync local state from controller state
      final state = _editState;
      if (!mounted) return;
      
      _setEditorState(() {
        _secondarySubtitles = state.secondarySubtitles;
        _originalSecondarySubtitles = state.originalSecondarySubtitles;
      });
      
      // Ensure video player gets updates
      _ensureVideoPlayerSubtitles();
    }

  Future<void> _showSyncModal() async {
    if (!mounted) return;
    await showEditorSyncSheet(
      context: context,
      subtitleLines: subtitleLines,
      subtitleCollectionId: widget.subtitleCollectionId,
      isVideoLoaded: _isVideoLoaded,
      videoPlayerKey: _videoPlayerKey,
      onRefresh: _refreshSubtitleLines,
    );
  }

  Future<void> _showInsertBannersModal() async {
    if (!mounted) return;
    await showEditorBannerSheet(
      context: context,
      subtitleCollectionId: widget.subtitleCollectionId,
      sessionId: widget.sessionId,
      subtitleLines: subtitleLines,
      onBannersInserted: _refreshSubtitleLines,
    );
  }

  Future<void> _showMalayalamNormalizationModal() async {
    if (!mounted) return;
    await showEditorNormalizationSheet(
      context: context,
      subtitleCollectionId: widget.subtitleCollectionId,
      subtitleLines: subtitleLines,
      onNormalizationComplete: _refreshSubtitleLines,
    );
  }

  Future<void> _showSettingsModal() async {
    if (!mounted) return;
    await showEditorSettingsSheet(
      context: context,
      onSettingsChanged: _controller.reloadPreferences,
    );
  }

  // Keyboard shortcut handlers

}
