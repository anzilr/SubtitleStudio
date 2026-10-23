part of '../../screen_edit_line.dart';

extension _EditLineTimeHelpers on EditSubtitleScreenState {
  // Store the initial values when a subtitle line is loaded
  void _storeInitialValues() {
    _initialOriginalText = _originalController.text;
    _initialEditedText = _editedController.text;
    _initialStartTime = _startTimeController.text;
    _initialEndTime = _endTimeController.text;
  }

  // Parse time string (HH:mm:ss,SSS) and set the corresponding controller
  void _parseTimeString(String timeString, bool isStartTime) {
    try {
      // If time string is valid, set it directly to the controller
      if (timeString.isNotEmpty) {
        if (isStartTime) {
          _startTimeController.text = timeString;
        } else {
          _endTimeController.text = timeString;
        }
      } else {
        // Set default values
        if (isStartTime) {
          _startTimeController.text = '00:00:00,000';
        } else {
          _endTimeController.text = '00:00:05,000';
        }
      }
    } catch (e) {
      // If parsing fails, set default values
      if (isStartTime) {
        _startTimeController.text = '00:00:00,000';
      } else {
        _endTimeController.text = '00:00:05,000';
      }
    }
  }

  // Get time string from the corresponding controller
  String _combineTimeComponents(bool isStartTime) {
    try {
      String timeString = isStartTime ? _startTimeController.text : _endTimeController.text;
      
      // If the controller is empty, return default time
      if (timeString.isEmpty) {
        return isStartTime ? '00:00:00,000' : '00:00:05,000';
      }
      
      return timeString;
    } catch (e) {
      // Return default time if there's an error
      return isStartTime ? '00:00:00,000' : '00:00:05,000';
    }
  }

  // Validate time components and show errors if any
  String? _validateTimeComponents(bool isStartTime) {
    try {
      String timeString = isStartTime ? _startTimeController.text : _endTimeController.text;
      return TimeValidator.validateTimeString(timeString);
    } catch (e) {
      return 'Invalid time format';
    }
  }

  // Validate that start time is less than end time
  String? _validateTimeOrder() {
    String startTime = _combineTimeComponents(true);
    String endTime = _combineTimeComponents(false);

    return TimeValidator.validateTimeOrder(startTime, endTime);
  }

  // Sync time from video for start time
  void _syncStartTimeFromVideo() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();
      final timeString = SubtitleSyncOperations.formatDuration(currentPosition);

      // Parse the time string into components
      _parseTimeString(timeString, true);

      // Update the combined controller
      _updateCombinedTimeControllers();

      // Show feedback to user
      SnackbarHelper.showSuccess(
        context,
        'Start time synced to current video position: $timeString',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Sync time from video for end time
  void _syncEndTimeFromVideo() {
    if (_isVideoLoaded && _videoPlayerKey.currentState != null) {
      final currentPosition =
          _videoPlayerKey.currentState!.getCurrentPosition();
      final timeString = SubtitleSyncOperations.formatDuration(currentPosition);

      // Parse the time string into components
      _parseTimeString(timeString, false);

      // Update the combined controller
      _updateCombinedTimeControllers();

      // Show feedback to user
      SnackbarHelper.showSuccess(
        context,
        'End time synced to current video position: $timeString',
        duration: const Duration(seconds: 2),
      );
    }
  }

  // Instant time controller updates (removed debouncing for maximum responsiveness)
  void _updateCombinedTimeControllers({bool validateTime = false}) {
    // Cancel any pending timer and update immediately
    _timeUpdateTimer?.cancel();

    if (!mounted) return;

    // Preserve cursor positions before updating text
    final startCursor = _startTimeController.selection;
    final endCursor = _endTimeController.selection;

    final newStartText = _combineTimeComponents(true);
    final newEndText = _combineTimeComponents(false);

    // Only update text if it actually changed to avoid cursor reset
    if (_startTimeController.text != newStartText) {
      _startTimeController.text = newStartText;
    } else {
      // Text didn't change, restore cursor position that might have been affected
      _startTimeController.selection = startCursor;
    }

    if (_endTimeController.text != newEndText) {
      _endTimeController.text = newEndText;  
    } else {
      // Text didn't change, restore cursor position that might have been affected
      _endTimeController.selection = endCursor;
    }

    // If validation is explicitly requested, validate and set errors
    if (validateTime) {
      _setEditLineState(() {
        _startTimeError = _validateTimeComponents(true);
        _endTimeError = _validateTimeComponents(false);
        _timeOrderError = _validateTimeOrder();
      });
    } else {
      // If there were previous validation errors, re-validate to potentially clear them
      // This allows real-time validation clearing when user fixes time values
      if (_startTimeError != null ||
          _endTimeError != null ||
          _timeOrderError != null) {
        _setEditLineState(() {
          _startTimeError = _validateTimeComponents(true);
          _endTimeError = _validateTimeComponents(false);
          _timeOrderError = _validateTimeOrder();
        });
      }
    }
  }

  // Build simplified time input field
  Widget _buildTimeComponentFields(String label, bool isStartTime) {
    final timeController =
        isStartTime ? _startTimeController : _endTimeController;
    final componentError =
        isStartTime ? _startTimeError : _endTimeError;

    return TimeComponentField(
      label: label,
      isStartTime: isStartTime,
      timeController: timeController,
      isVideoLoaded: _isVideoLoaded,
      fallbackComponentError: componentError,
      fallbackOrderError: _timeOrderError,
      onSync: isStartTime
          ? _syncStartTimeFromVideo
          : _syncEndTimeFromVideo,
      onTimeChanged: () => _updateCombinedTimeControllers(),
      onEditingComplete: () =>
          _updateCombinedTimeControllers(validateTime: true),
    );
  }


}
