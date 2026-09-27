import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/database/database_helper.dart'; // Add this import for clearAllApplicationData
import 'package:subtitle_studio/utils/app_info.dart'; // Add this import
import 'package:subtitle_studio/utils/update_manager.dart'; // Add this import
import 'package:subtitle_studio/screens/screen_help.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/utils/responsive_layout.dart';
import 'feedback_widget.dart';
import 'log_management_widget.dart';
import 'package:file_picker/file_picker.dart';
import '../themes/theme_controller.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:subtitle_studio/services/gemini_models_service.dart';
import 'package:url_launcher/url_launcher.dart';

part 'settings/settings_gemini_section.dart';
part 'settings/settings_waveform_section.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  final Function? onSettingsChanged;
  final String? initialSection;

  const SettingsSheet({super.key, this.onSettingsChanged, this.initialSection});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  void _setSettingsState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  bool _isMsoneEnabled = false;
  bool _isSaveToFileEnabled = false; // New variable for save to file toggle
  int _maxLineLength = 32; // Variable for max line length setting
  int _skipDurationSeconds = 10; // Variable for skip duration setting
  String _editLineLayout = 'layout1'; // Variable for edit line layout preference
  late TextEditingController _maxLineLengthController; // Controller for max line length text field
  late TextEditingController _skipDurationController; // Controller for skip duration text field
  late TextEditingController _geminiApiKeyController; // Controller for Gemini API key
  
  // Checkpoint system settings
  int _maxCheckpoints = 25; // Maximum checkpoints per session (0 = unlimited)
  int _snapshotInterval = 10; // Snapshot interval
  String _checkpointStrategy = 'hybrid'; // Checkpoint strategy: 'hybrid', 'snapshot', or 'delta'
  late TextEditingController _snapshotIntervalController;
  
  // Gemini AI settings
  String? _geminiApiKey;
  String _geminiModel = 'models/gemini-2.5-flash';
  List<GeminiModel> _availableModels = [];
  bool _isLoadingModels = false;

  // Waveform settings
  int _waveformMaxPixels = 500000;
  int _waveformSampleRateFactor = 16;
  double _waveformZoomMultiplier = 1.35;
  late TextEditingController _waveformMaxPixelsController;
  late TextEditingController _waveformSampleRateFactorController;
  late TextEditingController _waveformZoomMultiplierController;
  
  // Keys for scrolling to sections
  final GlobalKey _waveformSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _maxLineLengthController = TextEditingController();
    _skipDurationController = TextEditingController();
    _snapshotIntervalController = TextEditingController();
    _geminiApiKeyController = TextEditingController();
    _waveformMaxPixelsController = TextEditingController();
    _waveformSampleRateFactorController = TextEditingController();
    _waveformZoomMultiplierController = TextEditingController();
    _loadSettings();
    _fetchAvailableModels();
    
    // Scroll to section if specified
    if (widget.initialSection == 'waveform') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToWaveformSection();
      });
    }
  }
  
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
    
    setState(() {
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
    setState(() {
      _isLoadingModels = true;
    });

    try {
      final models = await GeminiModelsService.fetchAvailableModels();
      if (mounted) {
        setState(() {
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
            setState(() {
              _geminiModel = newModel;
            });
          } else if (_geminiModel != normalizedCurrentModel) {
            // Update to normalized format
            await PreferencesModel.setGeminiModel(normalizedCurrentModel);
            setState(() {
              _geminiModel = normalizedCurrentModel;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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

  Widget _buildFontSection() {
    final themeState = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final currentFontName = themeState.customFontName;

    return ListTile(
      leading: const Icon(Icons.font_download, color: Colors.indigo),
      title: const Text('Custom App Font'),
      subtitle: Text(currentFontName != null 
        ? 'Current: $currentFontName'
        : 'Using system default font'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentFontName != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => themeController.setCustomFont(null),
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['ttf', 'otf'],
              );
              
              if (result != null) {
                await themeController.setCustomFont(result.files.single.path);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.95, // 95% of screen height
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              
              // Make the content scrollable (excluding version)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // MSone Features Setting
                      ListTile(
                        leading: const Icon(Icons.auto_awesome, color: Colors.blue),
                        title: const Text('Enable MSone Features'),
                        subtitle: const Text('Enable advanced translation and editing features'),
                        trailing: Switch(
                          value: _isMsoneEnabled,
                          onChanged: (bool value) async {
                            await PreferencesModel.setMsoneEnabled(value);
                            setState(() {
                              _isMsoneEnabled = value;
                            });
                            if (widget.onSettingsChanged != null) {
                              widget.onSettingsChanged!();
                            }
                          },
                        ),
                      ),
                      
                      // New Toggle for Save to File
                      ListTile(
                        leading: const Icon(Icons.save, color: Colors.green),
                        title: const Text('Auto-Save to File'),
                        subtitle: const Text('When saving changes, also write to the file directly'),
                        trailing: Switch(
                  value: _isSaveToFileEnabled,
                  onChanged: (bool value) async {
                    await PreferencesModel.setSaveToFileEnabled(value);
                    setState(() {
                      _isSaveToFileEnabled = value;
                    });
                    if (widget.onSettingsChanged != null) {
                      widget.onSettingsChanged!();
                    }
                  },
                ),
              ),
              
              // Max Line Length Setting
              ListTile(
                leading: const Icon(Icons.straighten, color: Colors.orange),
                title: const Text('Max Characters Per Line'),
                subtitle: Text('Current limit: $_maxLineLength characters per line'),
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _maxLineLengthController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onFieldSubmitted: (value) async {
                      final newLength = int.tryParse(value);
                      if (newLength != null && newLength > 0 && newLength <= 200) {
                        await PreferencesModel.setMaxLineLength(newLength);
                        setState(() {
                          _maxLineLength = newLength;
                        });
                        // Update controller to show the new value
                        _maxLineLengthController.text = newLength.toString();
                        if (widget.onSettingsChanged != null) {
                          widget.onSettingsChanged!();
                        }
                      } else {
                        // Reset to current value if invalid
                        _maxLineLengthController.text = _maxLineLength.toString();
                      }
                    },
                  ),
                ),
              ),
              
              // Skip Duration Setting
              ListTile(
                leading: const Icon(Icons.fast_forward, color: Colors.deepPurple),
                title: const Text('Video Skip Duration'),
                subtitle: Text('Fast forward/reverse duration: $_skipDurationSeconds seconds'),
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _skipDurationController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onFieldSubmitted: (value) async {
                      final newDuration = int.tryParse(value);
                      if (newDuration != null && newDuration > 0 && newDuration <= 60) {
                        await PreferencesModel.setSkipDurationSeconds(newDuration);
                        setState(() {
                          _skipDurationSeconds = newDuration;
                        });
                        // Update controller to show the new value
                        _skipDurationController.text = newDuration.toString();
                        if (widget.onSettingsChanged != null) {
                          widget.onSettingsChanged!();
                        }
                      } else {
                        // Reset to current value if invalid
                        _skipDurationController.text = _skipDurationSeconds.toString();
                      }
                    },
                  ),
                ),
              ),
              
              // Custom Font Setting
              _buildFontSection(),

              // Switch Layout Setting (Desktop Only)
              if (ResponsiveLayout.shouldUseDesktopLayout(context))
                ListTile(
                  leading: const Icon(Icons.view_week, color: Colors.purple),
                  title: const Text('Switch Layout'),
                  subtitle: Text('Current layout: ${_editLineLayout == 'layout1' ? 'Editing Left, Video Right' : 'Video Left, Editing Right'}'),
                  trailing: Switch(
                    value: _editLineLayout == 'layout2',
                    onChanged: (bool value) async {
                      final newLayout = value ? 'layout2' : 'layout1';
                      await PreferencesModel.setSwitchLayout(newLayout);
                      setState(() {
                        _editLineLayout = newLayout;
                      });
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    },
                  ),
                ),
              
              const Divider(),
              
              // Max History Entries Setting
              ListTile(
                leading: const Icon(Icons.storage, color: Colors.blue),
                title: const Text('Maximum Edit History'),
                subtitle: Text(_maxCheckpoints == 0 
                    ? 'No Limit (Warning: May increase database size)'
                    : 'Limit: $_maxCheckpoints entries per session'),
                trailing: DropdownButton<int>(
                  value: _maxCheckpoints,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No Limit')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                    DropdownMenuItem(value: 100, child: Text('100')),
                    DropdownMenuItem(value: 200, child: Text('200')),
                    DropdownMenuItem(value: 500, child: Text('500')),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      await PreferencesModel.setMaxCheckpoints(value);
                      setState(() {
                        _maxCheckpoints = value;
                      });
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    }
                  },
                ),
              ),
              
              // Full Backup Interval Setting
              ListTile(
                leading: const Icon(Icons.save, color: Colors.orange),
                title: const Text('Full Backup Interval'),
                subtitle: Text('Create full backup every $_snapshotInterval changes\nLower = Faster undo, Higher = More space efficient'),
                trailing: SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _snapshotIntervalController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onFieldSubmitted: (value) async {
                      final newInterval = int.tryParse(value);
                      if (newInterval != null && newInterval >= 1 && newInterval <= 100) {
                        await PreferencesModel.setSnapshotInterval(newInterval);
                        setState(() {
                          _snapshotInterval = newInterval;
                          _snapshotIntervalController.text = newInterval.toString();
                        });
                      } else {
                        _snapshotIntervalController.text = _snapshotInterval.toString();
                      }
                      if (widget.onSettingsChanged != null) {
                        widget.onSettingsChanged!();
                      }
                    },
                  ),
                ),
              ),
              
              // Edit History Strategy Setting
              ListTile(
                leading: const Icon(Icons.account_tree, color: Colors.purple),
                title: const Text('Edit History Strategy'),
                subtitle: Text(_checkpointStrategy == 'hybrid' 
                    ? 'Smart Backup: Balanced accuracy and efficiency'
                    : _checkpointStrategy == 'snapshot'
                        ? 'Full Backup Only: Maximum accuracy, larger size'
                        : 'Changes Only: Maximum efficiency, potential issues'),
                trailing: DropdownButton<String>(
                  value: _checkpointStrategy,
                  items: const [
                    DropdownMenuItem(value: 'hybrid', child: Text('Smart Backup')),
                    DropdownMenuItem(value: 'snapshot', child: Text('Full Backup Only')),
                    DropdownMenuItem(value: 'delta', child: Text('Changes Only')),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      // Show warning dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_tree, color: Theme.of(context).primaryColor, size: 28),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Change Edit History Strategy',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (value == 'snapshot') ...[
                                          const Text('Full Backup Only:\n', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const Text('✓ Maximum accuracy - every save stores complete state'),
                                          const Text('✓ Fastest restoration'),
                                          const Text('✗ Large database size (10x more storage)'),
                                          const Text('✗ Slower save creation'),
                                        ] else if (value == 'delta') ...[
                                          const Text('Changes Only:\n', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const Text('✓ Minimum database size'),
                                          const Text('✓ Fast save creation'),
                                          const Text('✗ Potential restoration errors if chain breaks'),
                                          const Text('✗ Slower restoration (must apply all changes)'),
                                        ] else ...[
                                          const Text('Smart Backup (Recommended):\n', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const Text('✓ Balance of accuracy and efficiency'),
                                          const Text('✓ Periodic full backups for reliability'),
                                          const Text('✓ Track changes between backups for space savings'),
                                          const Text('✓ Configurable full backup interval'),
                                        ],
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Apply this strategy?',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          backgroundColor: Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Apply'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      
                      if (confirmed == true) {
                        await PreferencesModel.setCheckpointStrategy(value);
                        setState(() {
                          _checkpointStrategy = value;
                        });
                        if (widget.onSettingsChanged != null) {
                          widget.onSettingsChanged!();
                        }
                      }
                    }
                  },
                ),
              ),
              
              const Divider(),
              
              _buildGeminiSettingsSection(),
              _buildWaveformSettingsSection(),
              // Feedback Section with ExpansionTile
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // Remove internal dividers
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.feedback, color: Colors.blue),
                  title: const Text('Send Feedback'),
                  subtitle: const Text('Report bugs, suggest features, or share your thoughts'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  children: [
                    const FeedbackWidget(),
                  ],
                ),
              ),
              
              // Logging Section with cleaner ExpansionTile
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // Remove internal dividers
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('Logging'),
                  subtitle: const Text('Manage app logs and debugging information'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  children: [
                    const LogManagementWidget(),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Check for Updates
              ListTile(
                leading: const Icon(Icons.system_update, color: Colors.green),
                title: const Text('Check for Updates'),
                subtitle: const Text('Check for new app versions'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _checkForUpdates(),
              ),
              
              // Help & Documentation
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.teal),
                title: const Text('Help & Documentation'),
                subtitle: const Text('Learn how to use Subtitle Studio'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                },
              ),
              
              // Add more settings here as needed
              
              // Clear Preferences Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Confirmation dialog
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Reset Settings'),
                          content: const Text('Are you sure you want to reset all settings to default values?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Reset', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      
                      if (result == true) {
                        await PreferencesModel.clearAllPreferences();
                        await _loadSettings(); // Reload settings after clearing
                        if (widget.onSettingsChanged != null) {
                          widget.onSettingsChanged!();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset All Settings'),
                  ),
                ),
              ),
              
              // Clear All Data Button
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Show comprehensive warning dialog
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.delete_forever, color: Colors.red[700], size: 32),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Clear All Data',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber, color: Colors.red, size: 24),
                                            SizedBox(width: 8),
                                            Text(
                                              'WARNING',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'This action will permanently delete:',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        Text('• All subtitle files and editing sessions'),
                                        Text('• All app settings and preferences'),
                                        Text('• Edit history and checkpoints'),
                                        Text('• Video preferences and associations'),
                                        Text('• Cached waveform data'),
                                        Text('• All temporary files'),
                                        SizedBox(height: 12),
                                        Text(
                                          'Dictionary data will be preserved.',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'This action cannot be undone!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          backgroundColor: Colors.red[700],
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Clear All Data'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      
                      if (result == true && mounted) {
                        // Store navigator for safe navigation after async
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const AlertDialog(
                            content: Row(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 16),
                                Text('Clearing all data...'),
                              ],
                            ),
                          ),
                        );
                        
                        try {
                          // Clear all application data
                          await clearAllApplicationData();
                          
                          if (!mounted) return;
                          
                          // Close loading dialog
                          navigator.pop();
                          
                          // Show success message
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('All data cleared successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          
                          // Reload settings to show defaults
                          await _loadSettings();
                          
                          // Notify parent about changes
                          if (widget.onSettingsChanged != null) {
                            widget.onSettingsChanged!();
                          }
                          
                          // Close settings sheet and navigate to home
                          navigator.pop();
                          
                          // Navigate to home screen (clear stack)
                          navigator.pushNamedAndRemoveUntil(
                            '/',
                            (route) => false,
                          );
                        } catch (e) {
                          if (!mounted) return;
                          
                          // Close loading dialog
                          navigator.pop();
                          
                          // Show error message
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to clear data: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All Data'),
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
              
              // Sticky version section at the bottom
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                ),
                child: GestureDetector(
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Version ${AppInfo.versionWithBuild}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppInfo.abiInfo,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _maxLineLengthController.dispose();
    _skipDurationController.dispose();
    _snapshotIntervalController.dispose();
    _geminiApiKeyController.dispose();
    _waveformMaxPixelsController.dispose();
    _waveformSampleRateFactorController.dispose();
    _waveformZoomMultiplierController.dispose();
    super.dispose();
  }
}
