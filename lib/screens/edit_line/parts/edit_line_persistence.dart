part of '../../screen_edit_line.dart';

extension _EditLinePersistence on EditSubtitleScreenState {
  /// One persistence path for explicit Save and navigation autosave.
  /// Keep a failed write detached from the active line and preview.
  Future<bool> _commitCurrentDraftLine() async {
    final currentLine = _subtitleLine;
    final collection = _subtitle;
    if (currentLine == null || collection == null) return false;

    final result = await _editLineController.saveDraftLine(
      currentLine: currentLine,
      originalText: _originalController.text,
      editedText: _editedController.text,
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      initialOriginalText: _initialOriginalText,
      initialStartTime: _initialStartTime,
      initialEndTime: _initialEndTime,
      isEditMode: _isEditMode,
      insertLine: _isEditMode && !collection.lines.contains(currentLine),
      insertIndex: collection.lines.length,
    );
    if (!result.saved || result.savedLine == null) return false;
    if (!mounted) return true;

    // The controller already accepted the exact transactional result and
    // projected detached row copies. Adopt that snapshot instead of
    // mutating the prior Riverpod collection retained by this widget.
    final selectedState = _editLineState;
    final savedLine = selectedState.subtitleLine ?? result.savedLine!;
    final savedCollection = selectedState.subtitleCollection;
    if (savedCollection == null) {
      // Persistence succeeded; leave the current UI untouched if the
      // controller state is no longer available.
      return true;
    }
    _setEditLineState(() {
      _subtitleLine = savedLine;
      _subtitle = savedCollection;
      _currentIndexController.text = savedLine.index.toString();
    });
    _markSubtitlesForRegeneration();
    _generateSubtitles();
    return true;
  }

  /// Reload the requested cue. A stale/disposed route must not commit an
  /// earlier asynchronous result over a later navigation or touch controllers.
  Future<bool> _fetchSubtitleLine(Object? _subtitleId, int lineIndex) async {
    final loadGeneration = _navigationGuard.beginLoad();
    if (loadGeneration == null) return false;

    SubtitleCollection? collection;
    try {
      collection = await _editLineController.loadSubtitleCollection();
    } catch (error, stackTrace) {
      if (mounted && _navigationGuard.isCurrent(loadGeneration)) {
        logError(
          'Could not reload the selected subtitle line',
          error: error,
          stackTrace: stackTrace,
          context: 'EditSubtitleScreen._fetchSubtitleLine',
        );
      }
      return false;
    }
    if (!mounted || !_navigationGuard.isCurrent(loadGeneration)) return false;
    if (collection == null) {
      logWarning(
        'Edit Line collection unavailable while navigating',
        context: 'EditSubtitleScreen._fetchSubtitleLine',
      );
      return false;
    }

    if (lineIndex >= 0 && lineIndex < collection.lines.length) {
      final line = collection.lines[lineIndex];
      _setEditLineState(() {
        _subtitle = collection;
        _subtitleLine = line;
        _startTimeError = null;
        _endTimeError = null;
        _timeOrderError = null;
        _originalController.text = line.original;
        _editedController.text = line.edited?.replaceAll('<br>', '\n') ?? '';
        _startTimeController.text = line.startTime;
        _endTimeController.text = line.endTime;
        _currentIndexController.text = line.index.toString();
        _applyShowOriginalLine();
        _parseTimeString(line.startTime, true);
        _parseTimeString(line.endTime, false);
        _storeInitialValues();
      });

      _editLineController.synchronizeLoadedCue(
        collection: collection,
        line: line,
        visibleEditedText: _editedController.text,
      );
      _markSubtitlesForRegeneration();
      _generateSubtitles();
      if (_isVideoLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _navigationGuard.isCurrent(loadGeneration)) {
            _seekVideoToSubtitle();
          }
        });
      }
      return true;
    }

    // Only a request for the next slot may produce a new cue. The original
    // route index must not force creation when navigating to a valid row.
    if (lineIndex == collection.lines.length &&
        (widget.isNewSubtitle || _isEditMode)) {
      final newLine = SubtitleLine()
        ..index = collection.lines.length + 1
        ..startTime = '00:00:00,000'
        ..endTime = '00:00:05,000'
        ..original = ''
        ..edited = '';
      _setEditLineState(() {
        _subtitle = collection;
        _subtitleLine = newLine;
        _startTimeError = null;
        _endTimeError = null;
        _timeOrderError = null;
        _originalController.text = newLine.original;
        _editedController.text = '';
        _startTimeController.text = newLine.startTime;
        _endTimeController.text = newLine.endTime;
        _currentIndexController.text = newLine.index.toString();
        _parseTimeString(newLine.startTime, true);
        _parseTimeString(newLine.endTime, false);
        _storeInitialValues();
      });
      _editLineController.synchronizeLoadedCue(
        collection: collection,
        line: newLine,
        visibleEditedText: _editedController.text,
      );
      _markSubtitlesForRegeneration();
      _generateSubtitles();
      return true;
    }

    logWarning(
      'Edit Line navigation requested an invalid cue index',
      context: 'EditSubtitleScreen._fetchSubtitleLine',
    );
    return false;
  }

  Future<bool> _updateSubtitle(contxt) async {
    if (_subtitleLine != null) {
      // Ensure combined time controllers are up to date before checking for changes
      _updateCombinedTimeControllers();

      // Check if there are any changes to save
      if (!_hasUnsavedChanges()) {
        ScaffoldMessenger.of(contxt).showSnackBar(
          SnackBar(
            content: const Text('No changes to save'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(10),
          ),
        );
        return false;
      }

      // A change from existing edited text to '' is a deliberate blank cue.
      // _hasUnsavedChanges above already rejects no-op saves; do not reject
      // blank edits or whitespace-only subtitle text here.

      // Validate time before saving - enable validation and show errors
      _updateCombinedTimeControllers(validateTime: true);

      // Check if there are validation errors after validation
      if (_startTimeError != null ||
          _endTimeError != null ||
          _timeOrderError != null) {
        // Expand time section and highlight errors
        if (!_isTimeVisible) {
          _setEditLineState(() {
            _isTimeVisible = true;
          });

          // Auto-scroll to time section
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        }

        // Show error message
        String errorMessage =
            _startTimeError ??
            _endTimeError ??
            _timeOrderError ??
            'Time validation failed';
        ScaffoldMessenger.of(contxt).showSnackBar(
          SnackBar(
            content: Text('Time validation error: $errorMessage'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(10),
          ),
        );
        return false;
      }

      try {
        if (!await _commitCurrentDraftLine()) {
          throw StateError('Subtitle changes were not committed');
        }
        if (!mounted) return true;

        // Check if we should save directly to file
        if (_isSaveToFileEnabled && _subtitle != null) {
          // Export the exact post-transaction order and cue metadata.
          await _performEnhancedFileSave(
            contxt,
            List<SubtitleLine>.from(_subtitle!.lines),
          );
        } else {
          // Only show database-only success message if not saving to file
          if (!mounted) return true;

          ScaffoldMessenger.of(contxt).showSnackBar(
            SnackBar(
              content: const Text('Changes saved successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating, // Floating style
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0), // Rounded corners
              ),
              duration: const Duration(seconds: 2), // Duration of the snackbar
              dismissDirection: DismissDirection.up,
              margin: EdgeInsets.all(10),
            ),
          );
        }

        // Update initial values after successful save
        _storeInitialValues();

        // Clear validation errors after successful save
        _setEditLineState(() {
          _startTimeError = null;
          _endTimeError = null;
          _timeOrderError = null;
        });

        return true;
      } catch (e) {
        if (!mounted) return false;

        ScaffoldMessenger.of(contxt).showSnackBar(
          SnackBar(
            content: SafeArea(child: Text('Failed to save changes: $e')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // Floating style
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0), // Rounded corners
            ),
            duration: const Duration(seconds: 2), // Duration of the snackbar
            margin: const EdgeInsets.all(10.0), // Margin for floating behavior
          ),
        );
        return false;
      }
    }
    return false;
  }

  Future<bool> _updateSubtitleSilently() async {
    if (_subtitleLine != null) {
      // Ensure combined time controllers are up to date before checking for changes
      _updateCombinedTimeControllers();

      // Check if there are any changes to save
      if (!_hasUnsavedChanges()) {
        // No changes to save, navigation should still be allowed
        return true;
      }

      // Clearing edited text is a real edit; navigation autosave must persist
      // the deliberate blank just like a manual save.

      // Validate time components - show errors if validation fails during autosave
      _updateCombinedTimeControllers(validateTime: true);
      if (_startTimeError != null ||
          _endTimeError != null ||
          _timeOrderError != null) {
        // Expand time section and highlight errors
        if (!_isTimeVisible) {
          _setEditLineState(() {
            _isTimeVisible = true;
          });

          // Auto-scroll to time section
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        }

        // Show error message for autosave validation failure
        String errorMessage =
            _startTimeError ??
            _endTimeError ??
            _timeOrderError ??
            'Time validation failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot autosave - Time validation error: $errorMessage',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
        return false;
      }

      try {
        if (!await _commitCurrentDraftLine()) return false;

        // Clear validation errors after successful save
        if (mounted) {
          _setEditLineState(() {
            _startTimeError = null;
            _endTimeError = null;
            _timeOrderError = null;
          });
        }

        return true;
      } catch (e) {
        logError(
          'Failed to save changes',
          error: e,
          context: 'EditSubtitleScreen._saveChanges',
        );
        return false;
      }
    }
    return false;
  }

  /// Save to the selected original document when possible, and offer Save As
  /// when access is unavailable. All platform I/O and charset decisions live
  /// in the shared service; this method only presents UI and updates metadata.
  Future<void> _performEnhancedFileSave(
    BuildContext targetContext,
    List<SubtitleLine> updatedLines,
  ) async {
    final collection = _subtitle;
    if (collection == null) return;

    final saver = EditLineFileSaveService();
    late final Uint8List bytes;
    try {
      bytes = await saver.prepareBytes(collection, updatedLines);
    } catch (error) {
      // No write, picker, or metadata mutation after an incompatible charset.
      if (!mounted) return;
      ScaffoldMessenger.of(targetContext).showSnackBar(
        const SnackBar(
          content: Text(
            'This text cannot be saved in the selected encoding. '
            'Choose a compatible encoding in Project Settings.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool saved = false;
    try {
      saved = await saver.saveExisting(collection, bytes);
    } catch (error) {
      logWarning(
        'Edit Line original-file save unavailable (${error.runtimeType})',
        context: 'EditSubtitleScreen._performEnhancedFileSave',
      );
    }
    if (!mounted) return;

    if (saved) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        const SnackBar(
          content: Text('Changes saved to database and file'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final shouldPickLocation = await _showSaveLocationDialog();
    if (shouldPickLocation != true || !mounted) {
      ScaffoldMessenger.of(targetContext).showSnackBar(
        const SnackBar(
          content: Text('File save unavailable - changes saved to database only'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final location = await saver.saveAs(collection, bytes);
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(targetContext).showSnackBar(
          const SnackBar(
            content: Text('Save As canceled - changes saved to database only'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final updated = await _editLineController.updateSubtitleSaveLocation(
        filePath: location.filePath,
        originalFileUri: location.originalFileUri,
      );
      if (!mounted) return;
      if (updated) {
        collection.filePath = location.filePath;
        collection.originalFileUri = location.originalFileUri;
      }
      ScaffoldMessenger.of(targetContext).showSnackBar(
        SnackBar(
          content: Text(updated
              ? 'Changes saved to database and file (new location)'
              : 'File saved, but the project location could not be updated'),
          backgroundColor: updated ? Colors.green : Colors.orange,
        ),
      );
    } catch (error) {
      logWarning(
        'Edit Line Save As unavailable (${error.runtimeType})',
        context: 'EditSubtitleScreen._performEnhancedFileSave',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(targetContext).showSnackBar(
        const SnackBar(
          content: Text('Could not save the subtitle file to the new location.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _addInitialSubtitleLine() async {
    _setEditLineState(() {
      _isEditMode = true; // Switch to edit mode
      _isTimeVisible = true; // Show time fields
    });

    // Create an empty subtitle line
    final newLine =
        SubtitleLine()
          ..index = 1
          ..original = ""
          ..startTime = "00:00:00,000"
          ..endTime = "00:00:02,000";

    try {
      // Add to database
      final success = await _editLineController.addLine(newLine, 0);
      if (success) {
        // The database helper completes its transaction before returning.
        // Force refresh subtitle collection before fetching the new line
        _subtitle = await _editLineController.loadSubtitleCollection();

        // Refresh the screen with the new line
        _fetchSubtitleLine(widget.subtitleId, 0);
        if (!mounted) return;
        SubtitleOperations.showSuccessSnackbar(
          context,
          'New subtitle line added',
        );

        // Return true when navigating back to indicate success
        // This will trigger the refresh in the parent screen
        // Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        SnackbarHelper.showError(context, 'Failed to add subtitle line');
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Could not add the subtitle line. Please try again.');
    }
  }
}
