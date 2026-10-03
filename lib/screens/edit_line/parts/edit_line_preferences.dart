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

  Future<void> _reloadAllSettings() async {
    final preferences = await _loadPreferenceSnapshot();
    _applyPreferenceSnapshot(preferences);
  }

  Future<void> _saveColorHistory() async {
    await _editLineController.saveColorHistory(
      List<Color>.unmodifiable(_colorHistory),
    );
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

  Future<void> _saveAutoSaveWithNavigation(bool value) async {
    _setEditLineState(() {
      _autoSaveWithNavigation = value;
    });
    await _editLineController.savePreference(
      'autoSaveWithNavigation',
      value,
    );
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
