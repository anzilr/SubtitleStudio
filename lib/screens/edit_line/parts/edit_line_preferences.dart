part of '../../screen_edit_line.dart';

extension _EditLinePreferences on EditSubtitleScreenState {
  Future<EditLinePreferences> _loadPreferenceSnapshot() {
    return _editLineController.loadPreferencesSnapshot();
  }

  void _applyPreferenceSnapshot(EditLinePreferences preferences) {
    if (!mounted) return;

    _setEditLineState(() {
      _isMsoneEnabled = preferences.isMsoneEnabled;
      _showOriginalLine = preferences.showOriginalLine;
      _autoSaveWithNavigation = preferences.showOriginalLine
          ? preferences.autoSaveWithNavigation
          : true;
      _isSaveToFileEnabled = preferences.saveToFileEnabled;
      _autoResizeOnKeyboard = preferences.autoResizeOnKeyboard;
      _showOriginalTextField = preferences.showOriginalTextField;
      _resizeRatio = preferences.resizeRatio;
      _isResizeRatioLoaded = true;
      _mobileVideoResizeRatio = preferences.mobileVideoResizeRatio;
      _isMobileResizeRatioLoaded = true;
      _layoutPreference = preferences.layoutPreference;

      _colorHistory
        ..clear()
        ..addAll(preferences.colorHistory);

      if ((_isEditMode || widget.isNewSubtitle) &&
          preferences.videoPath != null) {
        _selectedVideoPath = preferences.videoPath;
        _isVideoVisible = true;
        _isVideoLoaded = true;
      }
    });

    _applyShowOriginalLine();
  }

  Future<void> _loadAllUiPreferences() async {
    final preferences = await _loadPreferenceSnapshot();
    _applyPreferenceSnapshot(preferences);
  }

  Future<void> _loadMsoneStatus() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _isMsoneEnabled = preferences.isMsoneEnabled;
    });
  }

  Future<void> _reloadAllSettings() async {
    final preferences = await _loadPreferenceSnapshot();
    _applyPreferenceSnapshot(preferences);
  }

  Future<void> _loadColorHistory() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _colorHistory
        ..clear()
        ..addAll(preferences.colorHistory);
    });
  }

  Future<void> _saveColorHistory() async {
    await _editLineController.saveColorHistory(
      List<Color>.unmodifiable(_colorHistory),
    );
  }

  Future<void> _loadShowOriginalLine() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _showOriginalLine = preferences.showOriginalLine;
    });
    _applyShowOriginalLine();
  }

  Future<void> _saveShowOriginalLine(bool value) async {
    _setEditLineState(() {
      _showOriginalLine = value;
      _autoSaveWithNavigation = !value;
    });

    await Future.wait([
      _editLineController.savePreference('showOriginalLine', value),
      _editLineController.savePreference(
        'autoSaveWithNavigation',
        !value,
      ),
    ]);

    _applyShowOriginalLine();
  }

  Future<void> _loadAutoSaveWithNavigation() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;

    _setEditLineState(() {
      _autoSaveWithNavigation = preferences.showOriginalLine
          ? preferences.autoSaveWithNavigation
          : true;
    });
  }

  Future<void> _saveAutoSaveWithNavigation(bool value) async {
    _setEditLineState(() {
      _autoSaveWithNavigation = value;
    });
    await _editLineController.savePreference(
      'autoSaveWithNavigation',
      value,
    );
  }

  Future<void> _loadSaveToFileEnabled() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _isSaveToFileEnabled = preferences.saveToFileEnabled;
    });
  }

  Future<void> _loadAutoResizeOnKeyboard() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _autoResizeOnKeyboard = preferences.autoResizeOnKeyboard;
    });
  }

  Future<void> _loadShowOriginalTextField() async {
    try {
      final preferences = await _loadPreferenceSnapshot();
      if (!mounted) return;
      _setEditLineState(() {
        _showOriginalTextField = preferences.showOriginalTextField;
      });
    } catch (e) {
      if (!mounted) return;
      _setEditLineState(() {
        _showOriginalTextField = true;
      });
    }
  }

  Future<void> _saveShowOriginalTextField(bool value) async {
    try {
      await _editLineController.savePreference(
        'showOriginalTextField',
        value,
      );
      if (!mounted) return;
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

  Future<void> _loadSavedVideoPath() async {
    if (!_isEditMode && !widget.isNewSubtitle) return;

    final preferences = await _loadPreferenceSnapshot();
    final savedPath = preferences.videoPath;
    if (savedPath == null || !mounted) return;

    _setEditLineState(() {
      _selectedVideoPath = savedPath;
      _isVideoVisible = true;
      _isVideoLoaded = true;
    });
  }

  Future<void> _loadResizeRatio() async {
    final preferences = await _loadPreferenceSnapshot();
    final ratio = preferences.resizeRatio;

    await logInfo(
      'Loading resize ratio: $ratio',
      context: 'EditSubtitleScreen._loadResizeRatio',
    );

    if (!mounted) return;
    _setEditLineState(() {
      _resizeRatio = ratio;
      _isResizeRatioLoaded = true;
    });
  }

  Future<void> _saveResizeRatio(double ratio) async {
    if (_lastLoggedRatio == null ||
        (ratio - _lastLoggedRatio!).abs() > 0.05) {
      await logInfo(
        '_saveResizeRatio called with: $ratio',
        context: 'EditSubtitleScreen._saveResizeRatio',
      );
      _lastLoggedRatio = ratio;
    }

    _setEditLineState(() {
      _resizeRatio = ratio;
    });

    _resizeRatioSaveTimer?.cancel();
    _resizeRatioSaveTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        await _editLineController.savePreference('resizeRatio', ratio);
      },
    );
  }

  Future<void> _loadMobileResizeRatio() async {
    if (!mounted) return;

    try {
      final preferences = await _loadPreferenceSnapshot();
      if (!mounted) return;

      _setEditLineState(() {
        _mobileVideoResizeRatio = preferences.mobileVideoResizeRatio;
        _isMobileResizeRatioLoaded = true;
      });
    } catch (e) {
      logError(
        'Error loading mobile resize ratio',
        error: e,
        context: 'EditSubtitleScreen._loadMobileResizeRatio',
      );

      if (!mounted) return;
      _setEditLineState(() {
        _mobileVideoResizeRatio = 0.4;
        _isMobileResizeRatioLoaded = true;
      });
    }
  }

  void _saveMobileResizeRatio(double ratio) {
    _mobileResizeRatioSaveTimer?.cancel();
    _mobileResizeRatioSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          await _editLineController.savePreference(
            'mobileVideoResizeRatio',
            ratio,
          );
        } catch (e) {
          logError(
            'Error saving mobile resize ratio',
            error: e,
            context: 'EditSubtitleScreen._saveMobileResizeRatio',
          );
        }
      },
    );
  }

  Future<void> _loadLayoutPreference() async {
    final preferences = await _loadPreferenceSnapshot();
    if (!mounted) return;
    _setEditLineState(() {
      _layoutPreference = preferences.layoutPreference;
    });
  }

  Future<void> _saveAutoResizeOnKeyboard(bool value) async {
    _setEditLineState(() {
      _autoResizeOnKeyboard = value;
    });
    await _editLineController.savePreference(
      'autoResizeOnKeyboard',
      value,
    );
  }

  void _applyShowOriginalLine() {
    if (_showOriginalLine &&
        _editedController.text.isEmpty &&
        _originalController.text.isNotEmpty) {
      _setEditLineState(() {
        _editedController.text = _originalController.text;
      });
    }
  }
}
