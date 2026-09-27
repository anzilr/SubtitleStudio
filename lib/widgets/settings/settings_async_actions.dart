part of '../settings_sheet.dart';

extension _SettingsAsyncActions on _SettingsSheetState {
  void _scrollToWaveformSection() {
    final context = _waveformSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _loadSettings() async {
    final msoneEnabled = await PreferencesModel.getMsoneEnabled();
    final saveToFileEnabled = await PreferencesModel.getSaveToFileEnabled(); // Load save-to-file setting
    final maxLineLength = await PreferencesModel.getMaxLineLength(); // Load max line length setting
    final skipDurationSeconds = await PreferencesModel.getSkipDurationSeconds(); // Load skip duration setting
    final editLineLayout = await PreferencesModel.getSwitchLayout(); // Load switch layout preference
    final maxCheckpoints = await PreferencesModel.getMaxCheckpoints();
    final snapshotInterval = await PreferencesModel.getSnapshotInterval();
    final checkpointStrategy = await PreferencesModel.getCheckpointStrategy();
    final geminiApiKey = await PreferencesModel.getGeminiApiKey();
    final geminiModel = await PreferencesModel.getGeminiModel();
    final waveformMaxPixels = await PreferencesModel.getWaveformMaxPixels();
    final waveformSampleRateFactor = await PreferencesModel.getWaveformSampleRateFactor();
    final waveformZoomMultiplier = await PreferencesModel.getWaveformZoomMultiplier();
    
    _setSettingsState(() {
      _isMsoneEnabled = msoneEnabled;
      _isSaveToFileEnabled = saveToFileEnabled;
      _maxLineLength = maxLineLength;
      _skipDurationSeconds = skipDurationSeconds;
      _editLineLayout = editLineLayout;
      _maxCheckpoints = maxCheckpoints;
      _snapshotInterval = snapshotInterval;
      _checkpointStrategy = checkpointStrategy;
      _geminiApiKey = geminiApiKey;
      _geminiModel = geminiModel;
      _waveformMaxPixels = waveformMaxPixels;
      _waveformSampleRateFactor = waveformSampleRateFactor;
      _waveformZoomMultiplier = waveformZoomMultiplier;
    });
    
    // Update the controller text to reflect the loaded values
    _maxLineLengthController.text = _maxLineLength.toString();
    _skipDurationController.text = _skipDurationSeconds.toString();
    _snapshotIntervalController.text = _snapshotInterval.toString();
    _geminiApiKeyController.text = _geminiApiKey ?? '';
    _waveformMaxPixelsController.text = _waveformMaxPixels.toString();
    _waveformSampleRateFactorController.text = _waveformSampleRateFactor.toString();
    _waveformZoomMultiplierController.text = _waveformZoomMultiplier.toStringAsFixed(2);
  }
  
  /// Fetch available Gemini models from API
  Future<void> _fetchAvailableModels() async {
    _setSettingsState(() {
      _isLoadingModels = true;
    });
  
    try {
      final models = await GeminiModelsService.fetchAvailableModels();
      if (mounted) {
        _setSettingsState(() {
          _availableModels = models;
          _isLoadingModels = false;
        });
  
        // Validate current model against fetched models
        if (_availableModels.isNotEmpty) {
          // Normalize model name for comparison (add 'models/' prefix if missing)
          final normalizedCurrentModel = _geminiModel.startsWith('models/')
              ? _geminiModel
              : 'models/$_geminiModel';
          
          final currentModelExists = _availableModels.any(
            (m) => m.name == normalizedCurrentModel,
          );
  
          if (!currentModelExists) {
            // Set to first available model
            final newModel = _availableModels.first.name ?? 'models/gemini-2.5-flash';
            await PreferencesModel.setGeminiModel(newModel);
            _setSettingsState(() {
              _geminiModel = newModel;
            });
          } else if (_geminiModel != normalizedCurrentModel) {
            // Update to normalized format
            await PreferencesModel.setGeminiModel(normalizedCurrentModel);
            _setSettingsState(() {
              _geminiModel = normalizedCurrentModel;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _setSettingsState(() {
          _isLoadingModels = false;
        });
      }
    }
  }
  
  /// Check for app updates manually
  Future<void> _checkForUpdates() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking for updates...'),
            ],
          ),
        ),
      );
  
      // Get diagnostic information for debugging
      final updateInfo = await UpdateManager.instance.checkForUpdate();
  
      // Remove loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
  
      if (updateInfo != null && mounted) {
        // Update is available
        UpdateManager.instance.showUpdateDialog(context, updateInfo);
      } else if (mounted) {
        // No update available - show simple success message
        SnackbarHelper.showSuccess(
          context,
          'You have the latest version!',
        );
      }
    } catch (e) {
      // Remove loading dialog if still showing
      if (mounted) {
        Navigator.of(context).pop();
      }
  
      // Show error message
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Failed to check for updates. Please try again later.',
        );
      }
    }
  }
}
