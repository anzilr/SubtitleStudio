import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/models/preferences_model.dart';
import 'package:subtitle_studio/database/database_helper.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/platform_file_handler.dart';
import 'package:subtitle_studio/utils/saf_path_converter.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/utils/subtitle_parser.dart';
import 'package:subtitle_studio/widgets/marked_lines_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
part 'project_settings/parts/project_settings_sections.dart';
part 'project_settings/parts/project_settings_path_helpers.dart';
part 'project_settings/parts/project_settings_media_actions.dart';
part 'project_settings/parts/project_settings_marked_actions.dart';

class ProjectSettingsSheet extends StatefulWidget {
  final Session session;
  final SubtitleCollection subtitleCollection;
  final VoidCallback onProjectUpdated;
  final Function(List<SimpleSubtitleLine>)? onSecondarySubtitlesLoaded;
  final Function()? onSecondarySubtitlesCleared;
  final Future<void> Function()? onSaveProject;
  final Future<void> Function()? onLoadVideo;

  const ProjectSettingsSheet({
    super.key,
    required this.session,
    required this.subtitleCollection,
    required this.onProjectUpdated,
    this.onSecondarySubtitlesLoaded,
    this.onSecondarySubtitlesCleared,
    this.onSaveProject,
    this.onLoadVideo,
  });

  @override
  State<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends State<ProjectSettingsSheet> with WidgetsBindingObserver {
  late TextEditingController _projectNameController;
  late TextEditingController _srtFileNameController;
  late String _selectedEncoding;
  String? _videoPath;
  String? _secondarySubtitlePath;
  bool _isSecondaryFromOriginal = false;
  bool _isLoading = true;
  Map<String, dynamic>? _sessionInfo;
  List<SubtitleLine> _markedLines = [];

  final List<String> _availableEncodings = [
    'UTF-8',
    'UTF-16',
    'ISO-8859-1',
    'Windows-1252',
    'ASCII',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _projectNameController = TextEditingController(text: widget.session.fileName);
    _srtFileNameController = TextEditingController(text: widget.subtitleCollection.fileName);
    _selectedEncoding = widget.subtitleCollection.encoding;
    _loadProjectData();

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _projectNameController.dispose();
    _srtFileNameController.dispose();
    super.dispose();
  }

  /// Start a timer to periodically check for external changes
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _refreshDataSilently();
      }
    });
  }

  /// Stop the periodic refresh timer
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Refresh data when app resumes (user might have returned from file picker)
      _refreshDataSilently();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when the widget's dependencies change (like when modal regains focus)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshDataSilently();
      }
    });
  }

  /// Silently refresh data without showing loading indicator
  Future<void> _refreshDataSilently() async {
    if (!mounted) return;
    
    try {
      bool hasChanges = false;
      
      // Check video path
      final currentVideoPath = await PreferencesModel.getVideoPath(widget.session.subtitleCollectionId);
      if (currentVideoPath != _videoPath) {
        _videoPath = currentVideoPath;
        hasChanges = true;
      }
      
      // Check secondary subtitle settings
      final currentSecondaryPath = await PreferencesModel.getSecondarySubtitlePath(widget.session.subtitleCollectionId);
      final currentIsOriginal = await PreferencesModel.getSecondaryIsOriginal(widget.session.subtitleCollectionId);
      
      if (currentSecondaryPath != _secondarySubtitlePath || currentIsOriginal != _isSecondaryFromOriginal) {
        _secondarySubtitlePath = currentSecondaryPath;
        _isSecondaryFromOriginal = currentIsOriginal;
        hasChanges = true;
      }
      
      // Check session info (for project file path)
      final session = await isar.sessions.get(widget.session.id);
      if (session != null && session.projectFilePath != widget.session.projectFilePath) {
        widget.session.projectFilePath = session.projectFilePath;
        hasChanges = true;
      }
      
      // Check marked lines count (avoid loading full list unless necessary)
      final currentMarkedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
      if (currentMarkedLines.length != _markedLines.length) {
        _markedLines = currentMarkedLines;
        hasChanges = true;
      }
      
      // Only trigger setState if there are actual changes
      if (hasChanges && mounted) {
        setState(() {});
      }
    } catch (e) {
      // Silently fail to avoid disrupting user experience
      if (kDebugMode) {
        print('Error silently refreshing project settings data: $e');
      }
    }
  }

  /// Public method to refresh video path from external calls
  Future<void> refreshVideoPath() async {
    await _loadVideoPath();
    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  /// Force refresh video path with multiple attempts
  Future<void> forceRefreshVideoPath() async {
    for (int i = 0; i < 5; i++) {
      await _loadVideoPath();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Public method to refresh all project data from external calls
  Future<void> refreshAllData() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Reload all data
      await _loadProjectData();
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showSnackBar(
          context,
          'Could not refresh project data. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Public method to refresh secondary subtitle data
  Future<void> refreshSecondarySubtitleData() async {
    if (!mounted) return;
    
    try {
      _secondarySubtitlePath = await PreferencesModel.getSecondarySubtitlePath(widget.session.subtitleCollectionId);
      _isSecondaryFromOriginal = await PreferencesModel.getSecondaryIsOriginal(widget.session.subtitleCollectionId);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showSnackBar(
          context,
          'Could not refresh secondary subtitle data. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// Public method to refresh session info (for project file path changes)
  Future<void> refreshSessionInfo() async {
    if (!mounted) return;
    
    try {
      // Refresh session from database
      final session = await isar.sessions.get(widget.session.id);
      if (session != null) {
        // Update the widget's session data if needed
        widget.session.projectFilePath = session.projectFilePath;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showSnackBar(
          context,
          'Could not refresh session information. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _loadProjectData() async {
    try {
      // Load session info
      _sessionInfo = await _getSessionInfo();
      
      // Load video path
      _videoPath = await PreferencesModel.getVideoPath(widget.session.subtitleCollectionId);
      
      // Load secondary subtitle settings
      _secondarySubtitlePath = await PreferencesModel.getSecondarySubtitlePath(widget.session.subtitleCollectionId);
      _isSecondaryFromOriginal = await PreferencesModel.getSecondaryIsOriginal(widget.session.subtitleCollectionId);
      
      // Load marked lines
      _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarHelper.showSnackBar(
          context,
          'Could not load project settings. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getSessionInfo() async {
    try {
      final subtitleLines = await fetchSubtitleLines(widget.subtitleCollection.id);
      final editedCount = subtitleLines.where((line) => line.edited != null && line.edited!.isNotEmpty).length;
      final totalLines = subtitleLines.length;
      final progress = totalLines > 0 ? editedCount / totalLines : 0.0;
      
      // Language detection with codes - same as HomeScreen
      Set<String> detectedLanguageCodes = {'EN'}; // Default English
      
      // Check for common non-Latin scripts
      for (final line in subtitleLines.take(10)) { // Check first 10 lines for performance
        final text = line.original + (line.edited ?? '');
        if (_containsScript(text, 'Malayalam')) detectedLanguageCodes.add('ML');
        if (_containsScript(text, 'Hindi')) detectedLanguageCodes.add('HI');
        if (_containsScript(text, 'Arabic')) detectedLanguageCodes.add('AR');
        if (_containsScript(text, 'Chinese')) detectedLanguageCodes.add('ZH');
        if (_containsScript(text, 'Japanese')) detectedLanguageCodes.add('JA');
        if (_containsScript(text, 'Korean')) detectedLanguageCodes.add('KO');
        if (_containsScript(text, 'Russian')) detectedLanguageCodes.add('RU');
      }
      
      return {
        'totalLines': totalLines,
        'editedLines': editedCount,
        'lastEditedIndex': widget.session.lastEditedIndex ?? 1,
        'progress': progress,
        'languageCodes': detectedLanguageCodes.join('/'),
        'languages': detectedLanguageCodes.toList(),
      };
    } catch (e) {
      return {
        'totalLines': 0,
        'editedLines': 0,
        'lastEditedIndex': 1,
        'progress': 0.0,
        'languageCodes': 'EN',
        'languages': ['EN'],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic color variables for adaptive theming
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: onSurfaceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.settings,
                        color: onSurfaceColor.withValues(alpha: 0.7),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Project Settings",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Manage project configuration and files",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                            ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Project Statistics at the top
                          _buildProjectStatsSection(),
                          const SizedBox(height: 24),
                          _buildBasicInfoSection(),
                          const SizedBox(height: 24),
                          _buildFileManagementSection(),
                          const SizedBox(height: 24),
                          _buildMediaPathsSection(),
                          const SizedBox(height: 24),
                          _buildEncodingSection(),
                          const SizedBox(height: 24),
                          _buildMarkedLinesSection(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      )
    );
  }


}
