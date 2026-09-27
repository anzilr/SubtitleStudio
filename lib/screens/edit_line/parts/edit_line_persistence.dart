part of '../../screen_edit_line.dart';

extension _EditLinePersistence on EditSubtitleScreenState {
  Future<void> _fetchSubtitleLine(subtitleId, lineIndex) async {
    // Clear any existing validation errors when loading a new line
    _setEditLineState(() {
      _startTimeError = null;
      _endTimeError = null;
      _timeOrderError = null;
    });

    // Fetch the subtitle document using the provided ID
    _subtitle = (await isar.subtitleCollections.get(widget.subtitleId))!;

    // Handle case when we're creating a new subtitle or at the end of the list
    if (widget.index > _subtitle!.lines.length) {
      if (widget.isNewSubtitle || _isEditMode) {
        // Create an empty subtitle line when in edit mode or creating a new subtitle
        _setEditLineState(() {
          _subtitleLine =
              SubtitleLine()
                ..index =
                    _subtitle!.lines.isEmpty ? 1 : _subtitle!.lines.length + 1
                ..startTime = "00:00:00,000"
                ..endTime = "00:00:05,000"
                ..original = ""
                ..edited = "";

          _originalController.text = _subtitleLine!.original;
          _editedController.text = _subtitleLine!.edited ?? '';
          _startTimeController.text = _subtitleLine!.startTime;
          _endTimeController.text = _subtitleLine!.endTime;
          _currentIndexController.text = _subtitleLine!.index.toString();

          // Parse time strings into individual components
          _parseTimeString(_subtitleLine!.startTime, true);
          _parseTimeString(_subtitleLine!.endTime, false);

          // Store initial values for change tracking
          _storeInitialValues();

          // Character counts updated by Cubit
        });

        // Mark subtitles for regeneration and generate for video player
        _markSubtitlesForRegeneration();
        _generateSubtitles();
        
        return;
      }
    }

    // Check if lineIndex is within valid range before accessing the array
    if (widget.index <= _subtitle!.lines.length &&
        lineIndex >= 0 &&
        lineIndex < _subtitle!.lines.length) {
      _subtitleLine = _subtitle?.lines[lineIndex];
      _setEditLineState(() {
        _originalController.text = _subtitleLine!.original;
        // Only set edited text if it exists, otherwise leave it empty
        _editedController.text =
            _subtitleLine!.edited != null
                ? _subtitleLine!.edited!.replaceAll('<br>', '\n')
                : '';
        _startTimeController.text = _subtitleLine!.startTime;
        _endTimeController.text = _subtitleLine!.endTime;
        _currentIndexController.text = _subtitleLine!.index.toString();
        // Apply show original line logic after setting controller values
        _applyShowOriginalLine();

        // Parse time strings into individual components
        _parseTimeString(_subtitleLine!.startTime, true);
        _parseTimeString(_subtitleLine!.endTime, false);

        // Store initial values for change tracking
        _storeInitialValues();

        // Character counts updated by Cubit
      });

      // Mark subtitles for regeneration and generate for video player
      _markSubtitlesForRegeneration();
      _generateSubtitles();

      // Seek video to current subtitle position if video is loaded
      if (_isVideoLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _seekVideoToSubtitle();
        });
      }
    } else {
      // Handle the case when the line index is out of range
      logError(
        'Invalid line index: $lineIndex, max index: ${_subtitle!.lines.length - 1}',
        context: 'EditSubtitleScreen._skipToLine',
      );
    }
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

      // Check if the edited text is empty but there are other changes
      if (_editedController.text.trim().isEmpty) {
        // Allow saving if there are changes to original text or time fields
        if (_originalController.text != _initialOriginalText ||
            _startTimeController.text != _initialStartTime ||
            _endTimeController.text != _initialEndTime) {
          // There are changes to save, continue with save operation
        } else {
          // No changes at all and empty edited text
          ScaffoldMessenger.of(contxt).showSnackBar(
            SnackBar(
              content: const Text(
                'Cannot save empty edited text with no other changes',
              ),
              backgroundColor: Colors.red,
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
      }

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
        if (_isEditMode) {
          // In edit mode, always update edited text (even if empty, to save the change)
          _subtitleLine!.edited = _editedController.text.replaceAll(
            '\n',
            '<br>',
          );
        } else {
          // In translation mode, update both original and edited text
          // Always update edited text to preserve the change (even if empty)
          _subtitleLine!.edited = _editedController.text.replaceAll(
            '\n',
            '<br>',
          );
          _subtitleLine!.original = _originalController.text;
        }

        // Update combined time controllers and use them for saving (validate during save)
        _updateCombinedTimeControllers(validateTime: true);
        _subtitleLine!.startTime = _startTimeController.text;
        _subtitleLine!.endTime = _endTimeController.text;

        // Handle new lines in edit mode
        if (_isEditMode && !_subtitle!.lines.contains(_subtitleLine)) {
          await Future.microtask(() async {
            await addSubtitleLine(
              widget.subtitleId,
              _subtitleLine!,
              _subtitle!.lines.length,
            );
          });
        } else {
          // Store the line state before changes for checkpoint
          final lineBeforeChanges = SubtitleLine()
            ..index = _subtitleLine!.index
            ..startTime = _initialStartTime
            ..endTime = _initialEndTime
            ..original = _initialOriginalText
            ..edited = _subtitleLine!.edited
            ..marked = _subtitleLine!.marked;
          
          // Call the database function for existing lines asynchronously
          await Future.microtask(() async {
            await saveSubtitleChangesToDatabase(
              _subtitle!.id,
              _subtitleLine!,
              _parseSubtitleTime,
              sessionId: widget.sessionId,
              beforeLine: lineBeforeChanges,
            );
          });
        }

        await Future.microtask(() async {
          await updateLastEditedIndex(widget.sessionId, _subtitleLine!.index);
        });

        // Mark subtitles for regeneration and regenerate subtitles for video player after saving changes (async)
        await Future.microtask(() {
          _markSubtitlesForRegeneration();
          _generateSubtitles();
        });

        // Check if we should save directly to file
        if (_isSaveToFileEnabled && _subtitle != null) {
          // Get the current edited content from the UI, not from database
          // Create an updated SubtitleLine with current form data
          final updatedLine =
              SubtitleLine()
                ..index = _subtitleLine!.index
                ..startTime = _startTimeController.text
                ..endTime = _endTimeController.text
                ..original = _originalController.text
                ..edited = _editedController.text.isEmpty ? null : _editedController.text
                ..marked = _subtitleLine!.marked;

          // Create a copy of all lines and update the current one
          final updatedLines = List<SubtitleLine>.from(_subtitle!.lines);
          final currentIndex = updatedLines.indexWhere((line) => line.index == _subtitleLine!.index);
          if (currentIndex != -1) {
            updatedLines[currentIndex] = updatedLine;
          }

          await _performEnhancedFileSave(contxt, updatedLines);
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

      // Allow saving if there are changes to original text or time fields,
      // even if edited text is empty
      if (_editedController.text.trim().isEmpty &&
          _originalController.text == _initialOriginalText &&
          _startTimeController.text == _initialStartTime &&
          _endTimeController.text == _initialEndTime) {
        // No changes at all, skip saving but allow navigation
        return true;
      }

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
        if (_isEditMode) {
          // In edit mode, always update edited text (even if empty, to save the change)
          _subtitleLine!.edited = _editedController.text.replaceAll(
            '\n',
            '<br>',
          );
        } else {
          // In translation mode, update both original and edited text
          // Always update edited text to preserve the change (even if empty)
          _subtitleLine!.edited = _editedController.text.replaceAll(
            '\n',
            '<br>',
          );
          _subtitleLine!.original = _originalController.text;
        }

        // Update combined time controllers and use them for saving (validate during save)
        _updateCombinedTimeControllers(validateTime: true);
        _subtitleLine!.startTime = _startTimeController.text;
        _subtitleLine!.endTime = _endTimeController.text;
        // Handle new lines in edit mode
        if (_isEditMode && !_subtitle!.lines.contains(_subtitleLine)) {
          await Future.microtask(() async {
            await addSubtitleLine(
              widget.subtitleId,
              _subtitleLine!,
              _subtitle!.lines.length,
            );
          });
        } else {
          // Store the line state before changes for checkpoint (for silent save)
          final lineBeforeChanges = SubtitleLine()
            ..index = _subtitleLine!.index
            ..startTime = _initialStartTime
            ..endTime = _initialEndTime
            ..original = _initialOriginalText
            ..edited = _subtitleLine!.edited
            ..marked = _subtitleLine!.marked;
          
          // Call the database function for existing lines asynchronously
          await Future.microtask(() async {
            await saveSubtitleChangesToDatabase(
              _subtitle!.id,
              _subtitleLine!,
              _parseSubtitleTime,
              sessionId: widget.sessionId,
              beforeLine: lineBeforeChanges,
            );
          });
        }

        await Future.microtask(() async {
          await updateLastEditedIndex(widget.sessionId, _subtitleLine!.index);
        });

        // Mark subtitles for regeneration and regenerate for video player after saving changes (async)
        await Future.microtask(() {
          _markSubtitlesForRegeneration();
          _generateSubtitles();
        });

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

  Future<void> _performEnhancedFileSave(BuildContext contxt, List<SubtitleLine> updatedLines) async {
    if (_subtitle == null) return;

    // Generate SRT content
    final srtContent = SrtCompiler.generateSrtContent(updatedLines);

    // Strategy 1: Try to save using originalFileUri (SAF URI)
    bool saveSuccessful = false;
    String? originalFileUri = _subtitle!.originalFileUri;
    
    if (originalFileUri!.isNotEmpty) {
      try {
        if (Platform.isAndroid && originalFileUri.startsWith('content://')) {
          // Use SAF to write to the content URI
          final success = await PlatformFileHandler.writeFile(
            content: srtContent,
            filePath: originalFileUri,
            fileName: _subtitle!.fileName,
            mimeType: 'application/x-subrip',
          );

          if (success) {
            saveSuccessful = true;
            if (mounted) {
              ScaffoldMessenger.of(contxt).showSnackBar(
                SnackBar(
                  content: const Text('Changes saved to database and file'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  duration: const Duration(seconds: 2),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
          }
        } else {
          // Desktop platform with regular file path
          String? filePath = originalFileUri;
          
          // Check if the path is a directory or doesn't end with .srt
          if (Directory(filePath).existsSync() || !filePath.toLowerCase().endsWith('.srt')) {
            // Create a proper file path by combining the directory with the filename
            String fileName = _subtitle!.fileName;
            if (!fileName.toLowerCase().endsWith('.srt')) {
              fileName = '$fileName.srt';
            }
            filePath = '$filePath/$fileName';
          }

          await File(filePath).writeAsString(srtContent);
          saveSuccessful = true;
          
          if (mounted) {
            ScaffoldMessenger.of(contxt).showSnackBar(
              SnackBar(
                content: const Text('Changes saved to database and file'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(10),
              ),
            );
          }
        }
      } catch (e) {
        // Strategy 1 failed, we'll try Strategy 2
        if (kDebugMode) {
          logWarning(
            'Failed to save using originalFileUri: $e',
            context: 'EditSubtitleScreen._saveChanges',
          );
        }
      }
    }

    // Strategy 2: If Strategy 1 failed, try using filePath
    if (!saveSuccessful) {
      String? filePath = _subtitle!.filePath;
      
      if (filePath!.isNotEmpty) {
        try {
          if (Platform.isAndroid && filePath.startsWith('content://')) {
            // Use SAF to write to the content URI
            final success = await PlatformFileHandler.writeFile(
              content: srtContent,
              filePath: filePath,
              fileName: _subtitle!.fileName,
              mimeType: 'application/x-subrip',
            );

            if (success) {
              saveSuccessful = true;
              if (mounted) {
                ScaffoldMessenger.of(contxt).showSnackBar(
                  SnackBar(
                    content: const Text('Changes saved to database and file'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            }
          } else {
            // Desktop platform with regular file path
            String? filePathToUse = filePath;
            
            // Check if the path is a directory or doesn't end with .srt
            if (Directory(filePathToUse).existsSync() || !filePathToUse.toLowerCase().endsWith('.srt')) {
              // Create a proper file path by combining the directory with the filename
              String fileName = _subtitle!.fileName;
              if (!fileName.toLowerCase().endsWith('.srt')) {
                fileName = '$fileName.srt';
              }
              filePathToUse = '$filePathToUse/$fileName';
            }

            await File(filePathToUse).writeAsString(srtContent);
            saveSuccessful = true;
            
            if (mounted) {
              ScaffoldMessenger.of(contxt).showSnackBar(
                SnackBar(
                  content: const Text('Changes saved to database and file'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  duration: const Duration(seconds: 2),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
          }
        } catch (e) {
          // Strategy 2 also failed
          if (kDebugMode) {
            logWarning(
              'Failed to save using filePath: $e',
              context: 'EditSubtitleScreen._saveChanges',
            );
          }
        }
      }
    }

    // Strategy 3: If both strategies failed, ask user to pick new location
    if (!saveSuccessful) {
      if (!mounted) return;
      
      // Show dialog asking user to pick new save location
      final shouldPickLocation = await _showSaveLocationDialog();
      
      if (shouldPickLocation == true && mounted) {
        try {
          String? newFilePath;
          String? newOriginalUri;
          
          if (Platform.isAndroid) {
            // Use SAF on Android
            final fileInfo = await PlatformFileHandler.saveNewFile(
              content: srtContent,
              fileName: _subtitle!.fileName.endsWith('.srt') 
                  ? _subtitle!.fileName 
                  : '${_subtitle!.fileName}.srt',
              mimeType: 'application/x-subrip',
            );
            
            if (fileInfo != null) {
              newFilePath = fileInfo.path;
              newOriginalUri = fileInfo.safUri;
              saveSuccessful = true;
            }
          } else if (Platform.isIOS) {
            // iOS platform - show save file dialog with bytes parameter
            final srtBytes = Uint8List.fromList(utf8.encode(srtContent));
            final result = await fp.FilePicker.platform.saveFile(
              dialogTitle: 'Save Subtitle File',
              fileName: _subtitle!.fileName.endsWith('.srt') 
                  ? _subtitle!.fileName 
                  : '${_subtitle!.fileName}.srt',
              type: fp.FileType.custom,
              allowedExtensions: ['srt'],
              bytes: srtBytes,
            );
            
            if (result != null) {
              newFilePath = result;
              newOriginalUri = result;
              saveSuccessful = true;
            }
          } else {
            // Desktop platform - show save file dialog
            final result = await fp.FilePicker.platform.saveFile(
              dialogTitle: 'Save Subtitle File',
              fileName: _subtitle!.fileName.endsWith('.srt') 
                  ? _subtitle!.fileName 
                  : '${_subtitle!.fileName}.srt',
              type: fp.FileType.custom,
              allowedExtensions: ['srt'],
            );
            
            if (result != null) {
              try {
                final file = File(result);
                await file.writeAsString(srtContent);
                newFilePath = result;
                newOriginalUri = result;
                saveSuccessful = true;
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(contxt).showSnackBar(
                    SnackBar(
                      content: const Text('Could not write the subtitle file to that location.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      margin: const EdgeInsets.all(10),
                    ),
                  );
                }
              }
            }
          }
          
          // Update the subtitle collection with new paths
          if (saveSuccessful && newFilePath != null) {
            _subtitle!.filePath = newFilePath;
            _subtitle!.originalFileUri = newOriginalUri;
            
            final updateSuccess = await updateSubtitleCollection(_subtitle!);
            
            if (updateSuccess && mounted) {
              ScaffoldMessenger.of(contxt).showSnackBar(
                SnackBar(
                  content: const Text('Changes saved to database and file (new location)'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  duration: const Duration(seconds: 2),
                  margin: const EdgeInsets.all(10),
                ),
              );
            } else if (mounted) {
              ScaffoldMessenger.of(contxt).showSnackBar(
                SnackBar(
                  content: const Text('File saved but failed to update file location in database'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  margin: const EdgeInsets.all(10),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(contxt).showSnackBar(
              SnackBar(
                content: const Text('Could not save the subtitle file to the new location.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.all(10),
              ),
            );
          }
        }
      }
    }
    
    // If all strategies failed and user didn't pick a new location
    if (!saveSuccessful && mounted) {
      ScaffoldMessenger.of(contxt).showSnackBar(
        SnackBar(
          content: const Text('File save failed - changes saved to database only'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(10),
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
      final success = await addSubtitleLine(widget.subtitleId, newLine, 0);
      if (success) {
        // The database helper completes its transaction before returning.
        // Force refresh subtitle collection before fetching the new line
        _subtitle = await isar.subtitleCollections.get(widget.subtitleId);

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
