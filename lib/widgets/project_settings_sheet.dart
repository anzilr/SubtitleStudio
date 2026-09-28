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
import 'dart:async';
part 'project_settings/parts/project_settings_sections.dart';
part 'project_settings/parts/project_settings_path_helpers.dart';

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
  Timer? _refreshTimer;

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
    
    // Start periodic refresh to detect external changes
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _stopPeriodicRefresh();
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

  Future<void> _locateVideoFile() async {
    if (_videoPath != null) {
      await _openFileLocation(_videoPath!);
    }
  }

  Future<void> _replaceVideoFile() async {
    if (widget.onLoadVideo != null) {
      try {
        final oldPath = _videoPath;

        // The Editor callback now completes only after file selection and
        // controller persistence finish, so polling is unnecessary.
        await widget.onLoadVideo!();
        if (!mounted) return;

        await _loadVideoPath();
        await _refreshDataSilently();
        if (!mounted) return;

        if (_videoPath != null && _videoPath != oldPath) {
          SnackbarHelper.showSnackBar(
            context,
            'Video file updated successfully',
            backgroundColor: Colors.green,
          );
        }
      } catch (e) {
        if (!mounted) return;
        SnackbarHelper.showSnackBar(
          context,
          'Could not update the video file. Please try again.',
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    // Fallback for standalone callers without an Editor callback.
    try {
      String? videoPath;

      if (Platform.isAndroid) {
        final fileInfo = await PlatformFileHandler.readFile(
          mimeTypes: ['video/*'],
        );
        videoPath = fileInfo?.path;
      } else {
        videoPath = await FilePickerSAF.pickFile(
          context: context,
          title: 'Select Video File',
          allowedExtensions: ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv'],
          pickText: 'Select Video File',
        );
      }

      if (videoPath == null || videoPath.isEmpty) return;

      await PreferencesModel.saveVideoPath(
        widget.session.subtitleCollectionId,
        videoPath,
      );
      if (!mounted) return;

      setState(() {
        _videoPath = videoPath;
      });

      SnackbarHelper.showSnackBar(
        context,
        'Video file updated successfully',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showSnackBar(
        context,
        'Could not update the video file. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Reload video path from preferences
  Future<void> _loadVideoPath() async {
    try {
      final savedPath = await PreferencesModel.getVideoPath(widget.session.subtitleCollectionId);
      if (mounted) {
        final oldPath = _videoPath;
        setState(() {
          _videoPath = savedPath;
        });
        if (kDebugMode) {
          print('Video path loaded: $oldPath -> $savedPath');
          if (savedPath != null) {
            print('Video path details:');
            print('  - Full path: $savedPath');
            print('  - Contains extension: ${savedPath.contains('.')}');
            print('  - Ends with slash: ${savedPath.endsWith('/') || savedPath.endsWith('\\')}');
            print('  - Is SAF URI: ${savedPath.startsWith('content://')}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading video path: $e');
      }
    }
  }

  Future<void> _clearVideoFile() async {
    await PreferencesModel.removeVideoPath(widget.session.subtitleCollectionId);
    setState(() {
      _videoPath = null;
    });
    
    SnackbarHelper.showSnackBar(
      context,
      'Video file cleared',
      backgroundColor: Colors.orange,
    );
  }

  Future<void> _locateSecondarySubtitle() async {
    if (_secondarySubtitlePath != null) {
      await _openFileLocation(_secondarySubtitlePath!);
    }
  }

  Future<void> _locateProjectFile() async {
    if (widget.session.projectFilePath != null) {
      await _openFileLocation(widget.session.projectFilePath!);
    }
  }

  Future<void> _locateSrtFile() async {
    if (widget.subtitleCollection.filePath != null) {
      await _openFileLocation(widget.subtitleCollection.filePath!);
    }
  }

  Future<void> _saveProjectFile() async {
    final saveProject = widget.onSaveProject;
    if (saveProject == null) return;

    try {
      await saveProject();
      if (!mounted) return;
      await _refreshDataSilently();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Project save callback failed: $e');
      }
    }
  }

  Future<void> _replaceSecondarySubtitle() async {
    // Show options: Load from file or Use original text
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Secondary Subtitle Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('Load from File'),
              subtitle: const Text('Import subtitle from an external file'),
              onTap: () {
                Navigator.pop(context);
                _loadSecondaryFromFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Use Original Text'),
              subtitle: const Text('Display original text as secondary track'),
              onTap: () {
                Navigator.pop(context);
                _useOriginalAsSecondary();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSecondaryFromFile() async {
    try {
      String? filePath;
      String? fileContent;
      String fileName = '';
      
      if (Platform.isAndroid) {
        final fileInfo = await PlatformFileHandler.readFile(
          mimeTypes: ['text/plain', 'application/x-subrip', 'text/vtt'],
        );
        
        if (fileInfo != null) {
          filePath = fileInfo.path;
          fileContent = fileInfo.contentAsString;
          fileName = fileInfo.fileName;
        }
      } else {
        filePath = await FilePickerSAF.pickFile(
          context: context,
          title: 'Pick a Subtitle File',
          allowedExtensions: ['.srt', '.vtt', '.ass', '.ssa'],
          pickText: 'Select Subtitle File',
        );
        
        final file = File(filePath!);
        fileContent = await file.readAsString();
        fileName = file.path.split('/').last;
            }

      if (filePath != null && fileContent != null) {
        List<SimpleSubtitleLine> parsedSubtitles = [];
        if (fileName.toLowerCase().endsWith('.srt')) {
          parsedSubtitles = SubtitleParser.parseSrt(fileContent);
        } else if (fileName.toLowerCase().endsWith('.vtt')) {
          parsedSubtitles = SubtitleParser.parseVtt(fileContent);
        } else if (fileName.toLowerCase().endsWith('.ass') || fileName.toLowerCase().endsWith('.ssa')) {
          parsedSubtitles = SubtitleParser.parseAss(fileContent);
        }

        if (parsedSubtitles.isNotEmpty) {
          widget.onSecondarySubtitlesLoaded?.call(parsedSubtitles);
          await PreferencesModel.saveSecondarySubtitlePath(widget.session.subtitleCollectionId, filePath);
          await PreferencesModel.setSecondaryIsOriginal(widget.session.subtitleCollectionId, false);
          
          setState(() {
            _secondarySubtitlePath = filePath;
            _isSecondaryFromOriginal = false;
          });
          
          // Trigger immediate refresh
          await _refreshDataSilently();
          
          SnackbarHelper.showSnackBar(
            context,
            'Secondary subtitle loaded successfully',
            backgroundColor: Colors.green,
          );
        } else {
          SnackbarHelper.showSnackBar(
            context,
            'Could not parse the subtitle file',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Project Settings failed to load secondary subtitle: $e');
      }
      SnackbarHelper.showSnackBar(
        context,
        'Could not load the secondary subtitle file. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _useOriginalAsSecondary() async {
    List<SimpleSubtitleLine> originalTextSubtitles = [];

    for (var line in widget.subtitleCollection.lines) {
      if (line.original.isNotEmpty) {
        originalTextSubtitles.add(SimpleSubtitleLine(
          index: line.index,
          startTime: line.startTime,
          endTime: line.endTime,
          text: line.original.replaceAll('<br>', '\n'),
        ));
      }
    }

    if (originalTextSubtitles.isNotEmpty) {
      widget.onSecondarySubtitlesLoaded?.call(originalTextSubtitles);
      await PreferencesModel.setSecondaryIsOriginal(widget.session.subtitleCollectionId, true);
      await PreferencesModel.removeSecondarySubtitlePath(widget.session.subtitleCollectionId);
      
      setState(() {
        _secondarySubtitlePath = null;
        _isSecondaryFromOriginal = true;
      });
      
      // Trigger immediate refresh
      await _refreshDataSilently();
      
      SnackbarHelper.showSnackBar(
        context,
        'Using original text as secondary subtitle',
        backgroundColor: Colors.green,
      );
    } else {
      SnackbarHelper.showSnackBar(
        context,
        'No original text available',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _clearSecondarySubtitle() async {
    widget.onSecondarySubtitlesCleared?.call();
    await PreferencesModel.removeSecondarySubtitlePath(widget.session.subtitleCollectionId);
    await PreferencesModel.setSecondaryIsOriginal(widget.session.subtitleCollectionId, false);
    
    setState(() {
      _secondarySubtitlePath = null;
      _isSecondaryFromOriginal = false;
    });
    
    // Trigger immediate refresh
    await _refreshDataSilently();
    
    SnackbarHelper.showSnackBar(
      context,
      'Secondary subtitle cleared',
      backgroundColor: Colors.orange,
    );
  }

  Future<void> _updateEncoding(String encoding) async {
    try {
      widget.subtitleCollection.encoding = encoding;
      await updateSubtitleCollection(widget.subtitleCollection);
      
      SnackbarHelper.showSnackBar(
        context,
        'Encoding updated to $encoding',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Project Settings failed to update encoding: $e');
      }
      SnackbarHelper.showSnackBar(
        context,
        'Could not update the text encoding. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  void _showMarkedLines() async {
    // Get both marked lines and all lines with comments
    final allLinesWithComments = await getAllSubtitleLinesWithComments(widget.session.subtitleCollectionId);
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => MarkedLinesSheet(
          markedLines: _markedLines,
          allLinesWithComments: allLinesWithComments,
          onLineSelected: (index) {
            // This could navigate to the specific line in the editor
            Navigator.pop(context); // Close project settings
          },
          onCommentUpdated: (index, comment) async {
            // Update comment in database and refresh marked lines
            try {
              await updateSubtitleLineComment(widget.session.subtitleCollectionId, index, comment);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to show updated comments
              
              SnackbarHelper.showSuccess(context, 
                comment != null ? 'Comment updated' : 'Comment deleted');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update comment: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the comment. Please try again.');
            }
          },
          onLineUnmarked: (index) async {
            // Unmark line and delete comment
            try {
              await unmarkSubtitleLine(widget.session.subtitleCollectionId, index);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to remove unmarked line
              
              SnackbarHelper.showSuccess(context, 'Line unmarked and comment deleted');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to unmark subtitle line: $e');
              }
              SnackbarHelper.showError(context, 'Could not unmark the subtitle line. Please try again.');
            }
          },
          onResolvedUpdated: (index, resolved) async {
            // Update resolved status in database
            try {
              await updateSubtitleLineResolved(widget.session.subtitleCollectionId, index, resolved);
              // Refresh marked lines list
              _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
              setState(() {}); // Trigger rebuild to show updated resolved status
              
              SnackbarHelper.showSuccess(context, 
                resolved ? 'Comment marked as resolved' : 'Comment marked as unresolved');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update resolved status: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the resolved status. Please try again.');
            }
          },
          onTextEdited: (index, newText) async {
            // Update edited text in database and refresh marked lines
            try {
              // Get the subtitle line from database
              final subtitle = await isar.subtitleCollections.get(widget.session.subtitleCollectionId);
              if (subtitle != null && index < subtitle.lines.length) {
                final updatedLine = subtitle.lines[index];
                updatedLine.edited = newText;
                
                // Save to database
                await saveSubtitleChangesToDatabase(
                  widget.session.subtitleCollectionId,
                  updatedLine,
                  (String time) {
                    // Parse time format "HH:mm:ss,SSS" to DateTime
                    final parts = time.split(',');
                    final hms = parts[0].split(':');
                    return DateTime(0, 1, 1, 
                      int.parse(hms[0]), 
                      int.parse(hms[1]), 
                      int.parse(hms[2]), 
                      int.parse(parts[1]));
                  },
                  sessionId: widget.session.id,
                );
                
                // Refresh marked lines list
                _markedLines = await getMarkedSubtitleLines(widget.session.subtitleCollectionId);
                setState(() {}); // Trigger rebuild to show updated text
                
                SnackbarHelper.showSuccess(context, 'Subtitle text updated');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Project Settings failed to update subtitle text: $e');
              }
              SnackbarHelper.showError(context, 'Could not update the subtitle text. Please try again.');
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    try {
      // Save project name
      final newProjectName = _projectNameController.text.trim();
      if (newProjectName.isNotEmpty && newProjectName != widget.session.fileName) {
        final session = await isar.sessions.get(widget.session.id);
        if (session != null) {
          session.fileName = newProjectName;
          await isar.writeTxn(() async {
            await isar.sessions.put(session);
          });
        }
      }

      widget.onProjectUpdated();
      
      SnackbarHelper.showSnackBar(
        context,
        'Changes saved successfully',
        backgroundColor: Colors.green,
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Project Settings failed to save project changes: $e');
      }
      SnackbarHelper.showSnackBar(
        context,
        'Could not save the project changes. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }
}
