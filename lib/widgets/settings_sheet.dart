import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/app/repositories/app_preferences_repository.dart';
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
part 'settings/settings_support_section.dart';
part 'settings/settings_destructive_section.dart';
part 'settings/settings_async_actions.dart';

class SettingsSheet extends ConsumerStatefulWidget {
  final Function? onSettingsChanged;
  final String? initialSection;

  const SettingsSheet({super.key, this.onSettingsChanged, this.initialSection});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  AppPreferencesRepository get _preferencesRepository =>
      ref.read(appPreferencesRepositoryProvider);

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
  Timer? _geminiApiKeySaveTimer;
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
    unawaited(_initializeSettings());
    
    // Scroll to section if specified
    if (widget.initialSection == 'waveform') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToWaveformSection();
      });
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
                            await _preferencesRepository.setMsoneEnabled(value);
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
                    await _preferencesRepository.setSaveToFileEnabled(value);
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
                        await _preferencesRepository.setMaxLineLength(newLength);
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
                        await _preferencesRepository.setSkipDurationSeconds(newDuration);
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
                      await _preferencesRepository.setSwitchLayout(newLayout);
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
                      await _preferencesRepository.setMaxCheckpoints(value);
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
                        await _preferencesRepository.setSnapshotInterval(newInterval);
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
                        await _preferencesRepository.setCheckpointStrategy(value);
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
              _buildSupportSection(),
              _buildDestructiveSettingsSection(),
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
    _geminiApiKeySaveTimer?.cancel();
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
