part of '../../screen_edit_line.dart';

extension _EditLinePreferences on EditSubtitleScreenState {
  // Sync with current video position and find nearest subtitle
  // Find the nearest subtitle index based on video position
  // Optimized settings loading with single setState
  Future<void> _loadMsoneStatus() async {
    final msoneEnabled = await PreferencesModel.getMsoneEnabled();
    if (mounted) {
      _setEditLineState(() {
        _isMsoneEnabled = msoneEnabled;
      });
    }
  }

  // Optimized settings reload with single setState
  Future<void> _reloadAllSettings() async {
    final results = await Future.wait([
      PreferencesModel.getMsoneEnabled(),
      PreferencesModel.getSaveToFileEnabled(),
      PreferencesModel.getAutoResizeOnKeyboard(),
      PreferencesModel.getMaxLineLength(),
    ]);

    if (mounted) {
      _setEditLineState(() {
        _isMsoneEnabled = results[0] as bool;
        _isSaveToFileEnabled = results[1] as bool;
        _autoResizeOnKeyboard = results[2] as bool;
        // results[3] was _maxLineLength - no longer needed (handled by Bloc)
      });

      // Character counts will be recalculated by Cubit when text changes
    }
  }

  // Optimized color history loading
  Future<void> _loadColorHistory() async {
    final colorStrings = await PreferencesModel.getColorHistory();
    if (mounted) {
      _setEditLineState(() {
        _colorHistory.clear();
        _colorHistory.addAll(
          colorStrings.map((color) => Color(int.parse(color))),
        );
      });
    }
  }

  Future<void> _saveColorHistory() async {
    final colorStrings =
        _colorHistory
            .map(
              (color) =>
                  '${(color.a * 255).round() << 24 | (color.r * 255).round() << 16 | (color.g * 255).round() << 8 | (color.b * 255).round()}',
            )
            .toList();
    await PreferencesModel.saveColorHistory(colorStrings);
  }

  Future<void> _loadShowOriginalLine() async {
    final showOriginalLine = await PreferencesModel.getShowOriginalLine();
    _setEditLineState(() {
      _showOriginalLine = showOriginalLine;
    });
  }

  Future<void> _saveShowOriginalLine(bool value) async {
    _setEditLineState(() {
      _showOriginalLine = value;
      // When enabling Show Original Line, default auto-save to false
      if (value) {
        _autoSaveWithNavigation = false;
      } else {
        _autoSaveWithNavigation =
            true; // Always true when Show Original Line is disabled
      }
    });

    await PreferencesModel.setShowOriginalLine(value);
    // Update the auto-save setting in preferences
    if (value) {
      await PreferencesModel.setAutoSaveWithNavigation(false);
    } else {
      await PreferencesModel.setAutoSaveWithNavigation(true);
    }

    _applyShowOriginalLine();
  }

  Future<void> _loadAutoSaveWithNavigation() async {
    final autoSave = await PreferencesModel.getAutoSaveWithNavigation();
    final showOriginal = await PreferencesModel.getShowOriginalLine();

    _setEditLineState(() {
      // Auto-save is true by default unless Show Original Line is enabled
      if (showOriginal) {
        _autoSaveWithNavigation = autoSave;
      } else {
        _autoSaveWithNavigation = true; // Always true in normal mode
      }
    });
  }

  Future<void> _saveAutoSaveWithNavigation(bool value) async {
    _setEditLineState(() {
      _autoSaveWithNavigation = value;
    });
    await PreferencesModel.setAutoSaveWithNavigation(value);
  }

  Future<void> _loadSaveToFileEnabled() async {
    final saveToFileEnabled =
        await PreferencesModel.getSaveToFileEnabled();
    _setEditLineState(() {
      _isSaveToFileEnabled = saveToFileEnabled;
    });
  }

  Future<void> _loadAutoResizeOnKeyboard() async {
    final autoResizeOnKeyboard = await PreferencesModel.getAutoResizeOnKeyboard();
    _setEditLineState(() {
      _autoResizeOnKeyboard = autoResizeOnKeyboard;
    });
  }

  // Load show original text field setting
  Future<void> _loadShowOriginalTextField() async {
    try {
      final showOriginalTextField =
          await PreferencesModel.getShowOriginalTextField();
      _setEditLineState(() {
        _showOriginalTextField = showOriginalTextField;
      });
    } catch (e) {
      // Default to true if loading fails
      _setEditLineState(() {
        _showOriginalTextField = true;
      });
    }
  }

  // Save show original text field setting
  Future<void> _saveShowOriginalTextField(bool value) async {
    try {
      await PreferencesModel.setShowOriginalTextField(value);
      _setEditLineState(() {
        _showOriginalTextField = value;
      });
    } catch (e) {
      logError(
        'Failed to save show original text field setting',
        error: e,
        context: 'EditSubtitleScreen._saveShowOriginalTextField',
      );
    }
  }

  // Load saved video path for edit mode
  Future<void> _loadSavedVideoPath() async {
    if (_isEditMode || widget.isNewSubtitle) {
      final savedPath = await PreferencesModel.getVideoPath(
        widget.subtitleId,
      );
      if (savedPath != null && mounted) {
        _setEditLineState(() {
          _selectedVideoPath = savedPath;
          _isVideoVisible = true;
          _isVideoLoaded = true;
        });
      }
    }
  }

  // Load resize ratio preference
  Future<void> _loadResizeRatio() async {
    final ratio = await PreferencesModel.getEditLineResizeRatio();
    await logInfo(
      'Loading resize ratio: $ratio',
      context: 'EditSubtitleScreen._loadResizeRatio',
    );
    if (mounted) {
      _setEditLineState(() {
        _resizeRatio = ratio;
        _isResizeRatioLoaded = true;
      });
      await logInfo(
        'Updated _resizeRatio to: $_resizeRatio, loaded: $_isResizeRatioLoaded',
        context: 'EditSubtitleScreen._loadResizeRatio',
      );
    }
  }

  // Save resize ratio preference with debouncing
  Future<void> _saveResizeRatio(double ratio) async {
    // Only log when ratio changes significantly
    if (_lastLoggedRatio == null || (ratio - _lastLoggedRatio!).abs() > 0.05) {
      await logInfo(
        '_saveResizeRatio called with: $ratio',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
      _lastLoggedRatio = ratio;
    }

    _setEditLineState(() {
      _resizeRatio = ratio;
    });

    // Cancel any existing timer
    _resizeRatioSaveTimer?.cancel();

    // Start a new timer to save after a short delay
    _resizeRatioSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      await logInfo(
        'Timer saving ratio to SharedPreferences: $ratio',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
      await PreferencesModel.setEditLineResizeRatio(ratio);
      await logInfo(
        'Save completed - verification: ${await PreferencesModel.getEditLineResizeRatio()}',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
    });
  }

  /// Load mobile video resize ratio from preferences
  Future<void> _loadMobileResizeRatio() async {
    if (!mounted) return;
    
    try {
      final ratio = await PreferencesModel.getMobileVideoResizeRatio();
      if (mounted) {
        _setEditLineState(() {
          _mobileVideoResizeRatio = ratio;
          _isMobileResizeRatioLoaded = true;
        });
      }
    } catch (e) {
      logError(
        'Error loading mobile resize ratio',
        error: e,
        context: 'EditSubtitleScreen._loadMobileResizeRatio',
      );
      if (mounted) {
        _setEditLineState(() {
          _mobileVideoResizeRatio = 0.4; // Default fallback
          _isMobileResizeRatioLoaded = true;
        });
      }
    }
  }

  /// Save mobile video resize ratio with debouncing
  void _saveMobileResizeRatio(double ratio) {
    // Cancel any existing timer
    _mobileResizeRatioSaveTimer?.cancel();
    
    // Set up a new timer with 500ms delay
    _mobileResizeRatioSaveTimer = Timer(Duration(milliseconds: 500), () async {
      try {
        await PreferencesModel.setMobileVideoResizeRatio(ratio);
      } catch (e) {
        logError(
          'Error saving mobile resize ratio',
          error: e,
          context: 'EditSubtitleScreen._saveMobileResizeRatio',
        );
      }
    });
  }

  /// Load layout preference for desktop layout switching
  Future<void> _loadLayoutPreference() async {
    final layout = await PreferencesModel.getSwitchLayout();
    if (mounted) {
      _setEditLineState(() {
        _layoutPreference = layout;
      });
    }
  }

  Future<void> _saveAutoResizeOnKeyboard(bool value) async {
    _setEditLineState(() {
      _autoResizeOnKeyboard = value;
    });
    await PreferencesModel.setAutoResizeOnKeyboard(value);
  }

  void _applyShowOriginalLine() {
    if (_showOriginalLine &&
        (_editedController.text.isEmpty || _editedController.text == '') &&
        _originalController.text.isNotEmpty) {
      _setEditLineState(() {
        _editedController.text = _originalController.text;
      });
    }
  }


}
