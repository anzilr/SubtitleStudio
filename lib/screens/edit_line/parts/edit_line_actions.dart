part of '../../screen_edit_line.dart';

extension _EditLineActions on EditSubtitleScreenState {
  /// Check if there are any validation errors that would prevent navigation
  bool _hasValidationErrors() {
    return _startTimeError != null ||
        _endTimeError != null ||
        _timeOrderError != null;
  }

  // Helper function to parse subtitle time
  DateTime _parseSubtitleTime(String time) {
    // Assuming the time format is "HH:mm:ss,SSS" (e.g., "00:01:23,456")
    List<String> parts = time.split(',');
    List<String> hms = parts[0].split(':');
    int hours = int.parse(hms[0]);
    int minutes = int.parse(hms[1]);
    int seconds = int.parse(hms[2]);
    int milliseconds = int.parse(parts[1]);

    return DateTime(0, 1, 1, hours, minutes, seconds, milliseconds);
  }

  // Show edit line menu modal
  void _showEditLineMenuModal() {
    showEditLineMenu(
      context: context,
      isEditMode: _isEditMode,
      isNewSubtitle: widget.isNewSubtitle,
      isVideoLoaded: _isVideoLoaded,
      hasSecondarySubtitles: _secondarySubtitles.isNotEmpty,
      showSecondarySubtitles: _showSecondarySubtitles,
      autoResizeOnKeyboard: _autoResizeOnKeyboard,
      isMobilePlatform: ResponsiveLayout.isMobilePlatform(),
      showOriginalLine: _showOriginalLine,
      autoSaveWithNavigation: _autoSaveWithNavigation,
      showOriginalTextField: _showOriginalTextField,
      isFormattedView: isRawEnabled,
      isMarked: _subtitleLine?.marked ?? false,
    ).then(_handleEditLineMenuSelection);
  }

  // Handle edit line menu selection
  // Toggle mark status of the current subtitle line
  Future<void> _toggleMarkLine() async {
    if (_subtitleLine == null) return;

    final currentMarked = _subtitleLine!.marked;
    final newMarked = !currentMarked;
    final lineIndex = _subtitleLine!.index - 1;

    logInfo(
      'ToggleMarkLine: subtitleId=${widget.subtitleId}, subtitleIndex=${_subtitleLine!.index}, arrayIndex=$lineIndex, newMarked=$newMarked',
      context: 'EditSubtitleScreen._toggleMarkLine',
    );

    try {
      final success = await markSubtitleLine(
        widget.subtitleId,
        lineIndex,
        newMarked,
      );
      if (success) {
        _setEditLineState(() {
          _subtitleLine!.marked = newMarked;
        });

        // Refresh subtitle collection data and update video player
        _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;
        _markSubtitlesForRegeneration();
        _generateSubtitles();

        // Show success message
        SnackbarHelper.showSuccess(
          context,
          newMarked ? 'Line marked' : 'Line unmarked',
          duration: const Duration(seconds: 1),
        );
      } else {
        SnackbarHelper.showError(context, 'Failed to update mark status - check debug log for details');
      }
    } catch (e) {
      SnackbarHelper.showError(context, 'Could not update mark status. Please try again.');
    }
  }

  // Show comment dialog for current line
  // Show marked lines modal
  // Show Edit History modal (responsive dialog)
  // Show jump to line modal
  Future<void> _showJumpToLineModal() async {
    if (_subtitle?.lines == null || _subtitle!.lines.isEmpty) {
      SnackbarHelper.showError(context, 'No subtitle lines available');
      return;
    }

    final totalLines = _subtitle!.lines.length;
    final currentLine = _subtitleLine?.index.toString() ?? '1';

    showGotToLineModal(
      context: context,
      initialValue: currentLine,
      hintText: totalLines,
      title: 'Jump to Line',
      onSubmitted: (value) {
        final lineNumber = int.tryParse(value);
        if (lineNumber != null && lineNumber >= 1 && lineNumber <= totalLines) {
          // Convert 1-based line number to 0-based index for _skipToLine
          _skipToLine(widget.subtitleId, lineNumber - 1);
        }
      },
    );
  }

  String _selectedOrFullOriginalText() {
    final selection = _originalController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      return _originalController.text.substring(
        selection.start,
        selection.end,
      );
    }
    return _originalController.text;
  }

  void _showOlamDictionary() {
    showOlamDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  void _showUrbanDictionary() {
    showUrbanDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  void _showMsoneDictionary() {
    showMsoneDictionarySheet(
      context: context,
      initialSearchTerm: _selectedOrFullOriginalText(),
      onSelectTranslation: (text) {
        _editedController.text = text;
      },
    );
  }

  // Show Secondary Subtitle modal
  // Show AI Explanation - triggers the AI explanation feature
  Future<void> _showAiExplanation() async {
    final currentText = _editedController.text.isEmpty
        ? _originalController.text
        : _editedController.text;

    final aiContext = EditLineAiContextBuilder.build(
      lines: _subtitle?.lines ?? const <SubtitleLine>[],
      currentIndex: (_subtitleLine?.index ?? 1) - 1,
      useEditedText: _isEditMode,
      contextRadius: 3,
    );

    if (!mounted) return;
    AiExplanationSheet.show(
      context: context,
      currentText: currentText,
      previousLines: aiContext.previousLines,
      nextLines: aiContext.nextLines,
      allLines: aiContext.allLines,
      currentIndex: aiContext.currentIndex,
      originalAllLines: aiContext.originalAllLines,
      editedAllLines: aiContext.editedAllLines,
    );
  }

  // Handle mark/unmark from video player fullscreen controls
  Widget _buildContentWithoutVideo(Column originalContent) {
    // Create a modified version of the original content without the video player
    final children = originalContent.children;
    final modifiedChildren = <Widget>[];

    for (final child in children) {
      // Skip the video player widget (SizedBox with height 240 containing VideoPlayerWidget)
      if (child is SizedBox && child.height == 240) {
        continue; // Skip video player
      }
      // Skip the spacing after video player
      else if (modifiedChildren.isNotEmpty &&
          modifiedChildren.last is SizedBox &&
          child is SizedBox &&
          child.height == 1) {
        continue; // Skip spacing after video
      } else {
        modifiedChildren.add(child);
      }
    }

    return Column(children: modifiedChildren);
  }


}
