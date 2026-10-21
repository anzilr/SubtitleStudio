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
    // May be invoked by State.dispose(): never access ref via the
    // _editLineController getter while the ConsumerState is deactivating.
    await _colorHistoryRepository.saveColorHistory(
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

  void _saveResizeRatio(double ratio) {
    _setEditLineState(() {
      _resizeRatio = ratio;
    });
    _editLineController.scheduleResizeRatio(ratio);

    if (_lastLoggedRatio == null ||
        (ratio - _lastLoggedRatio!).abs() > 0.05) {
      _lastLoggedRatio = ratio;
      unawaited(
        logInfo(
          '_saveResizeRatio called with: $ratio',
          context: 'EditSubtitleScreen._saveResizeRatio',
        ),
      );
    }
  }

  void _saveMobileResizeRatio(double ratio) {
    // ResizableSplitView manages its drag frames without a parent rebuild.
    _mobileVideoResizeRatio = ratio;
    _editLineController.scheduleMobileVideoResizeRatio(ratio);
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
