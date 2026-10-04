part of '../../screen_edit.dart';

extension _EditNavigation on _EditScreenState {
  Future<void> _scrollToIndexWithLoading(int cueNumber) async {
    final index = cueNumberToListIndex(cueNumber);
    if (index == null || index >= subtitleLines.length) return;

    IsolatedLoaderController.show(context);

    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final attached = await _waitForItemScrollController();
      if (!attached || !mounted) {
        _setEditorState(() {
          _highlightedIndex = index;
        });
        return;
      }

      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      if (!mounted) return;
      _setEditorState(() {
        _highlightedIndex = index;
      });
    } finally {
      IsolatedLoaderController.hide();
    }
  }

  Future<bool> _waitForItemScrollController({
    int maxFrames = 10,
  }) async {
    for (int frame = 0; frame < maxFrames; frame++) {
      if (_itemScrollController.isAttached) return true;
      if (!mounted) return false;
      await WidgetsBinding.instance.endOfFrame;
    }
    return _itemScrollController.isAttached;
  }

  void _updateScrollbarPosition() {
    if (_isDraggingScrollbar || !mounted) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty || subtitleLines.isEmpty) return;

    final firstVisible =
        positions.where((pos) => pos.itemLeadingEdge >= 0).firstOrNull;
    if (firstVisible != null) {
      _scrollbarThumbOffset.value =
          firstVisible.index / subtitleLines.length;
    }
  }

  Future<void> scrollToIndex(int index) async {
    if (index < 0 || index >= subtitleLines.length) return;
    if (!await _waitForItemScrollController()) return;

    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  // Direct navigation method that only updates UI state without side effects.
  Future<void> _navigateToIndex(int index) async {
    if (index < 0 || index >= subtitleLines.length || _isNavigating) {
      return;
    }

    _isNavigating = true;
    try {
      if (!mounted) return;
      _setEditorState(() {
        _highlightedIndex = index;
      });

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await scrollToIndex(index);
    } finally {
      _isNavigating = false;
    }
  }

  void _onSubtitleChange(int index) {
    if (index < 0 || index >= subtitleLines.length) return;

    // Cancel previous timer to implement debouncing
    _subtitleChangeDebouncer?.cancel();
    
    // Debounce: only update after 50ms of no changes
    // This reduces rebuilds from ~25 per change to 1
    _subtitleChangeDebouncer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      
      debugPrint('_onSubtitleChange called: updating _highlightedIndex from $_highlightedIndex to $index');
      
      _setEditorState(() {
        _highlightedIndex = index;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(scrollToIndex(index));
        }
      });
    });
  }

  void _onVideoPositionChanged(Duration position) {
    if (!mounted) return;

    // Playback callbacks are frequent. Updating this cache must not rebuild the
    // entire Editor; Waveform owns its playback-position rendering state.
    _lastVideoPosition = position;
    ref
        .read(waveformControllerProvider.notifier)
        .dispatch(UpdatePlaybackPosition(position));
  }

  void _highlightIndex(int index) {
    if (index < 0 || index >= subtitleLines.length) return;

    if (mounted) {
      _setEditorState(() {
        _highlightedIndex = index;
      });
    }
  }

  void _seekToSubtitle(int index) {
    if (index < 0 || index >= subtitleLines.length) return;

    final startTime = parseTimeString(subtitleLines[index].startTime);
    if (_videoPlayerKey.currentState != null &&
        _videoPlayerKey.currentState!.isInitialized()) {
      // Add 50ms offset to ensure subtitle is visible after seeking
      // This prevents the subtitle from disappearing when seeking to exact start time
      final seekPosition = startTime + const Duration(milliseconds: 50);
      _videoPlayerKey.currentState!.seekTo(seekPosition);
      _lastVideoPosition = seekPosition;
      ref
          .read(waveformControllerProvider.notifier)
          .dispatch(UpdatePlaybackPosition(seekPosition));
      _onSubtitleChange(index);
    }
  }

  // Seek video to currently highlighted subtitle (useful for manual sync)
  void _seekVideoToHighlightedSubtitle() {
    if (_highlightedIndex != null && _highlightedIndex! >= 0 && _highlightedIndex! < subtitleLines.length) {
      _seekToSubtitle(_highlightedIndex!);
    }
  }


}
