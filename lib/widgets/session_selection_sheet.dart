import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/project_manager.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/screens/edit/edit_screen_host.dart';
import 'package:subtitle_studio/widgets/session_selection/session_project_import_repository.dart';
part 'session_selection/locate_srt_sheet.dart';
import 'package:subtitle_studio/utils/srt_compiler.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/platform_file_handler.dart';

/// Session Selection Sheet Widget
/// 
/// This widget provides a bottom modal sheet for selecting an existing session
/// to replace with imported project data. It displays all sessions from the 
/// database and allows the user to choose which one to update.
class SessionSelectionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> projectData;
  final String? originalFileUri;
  final Function(Session)? onSessionReplaced;
  final Function(Session)? onSessionCreated;
  final Function(Session)? onProjectImported; // New callback for home screen refresh

  const SessionSelectionSheet({
    super.key,
    required this.projectData,
    this.originalFileUri,
    this.onSessionReplaced,
    this.onSessionCreated,
    this.onProjectImported,
  });

  @override
  ConsumerState<SessionSelectionSheet> createState() => _SessionSelectionSheetState();
}

class _SessionSelectionSheetState extends ConsumerState<SessionSelectionSheet> {
  List<Session> _sessions = [];
  bool _isLoading = true;
  bool _isReplacing = false;
  bool _isCreating = false;
  Session? _selectedSession;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// Ask user to select the SRT file location
  /// Since .msone projects are portable but SRT files may be in different locations
  /// Returns a Map with 'filePath', 'fileName', and 'safUri' keys
  Future<Map<String, String?>?> _selectSrtFilePath({Session? existingSession}) async {
    try {
      // Get the original filename and filepath from project data to help user identify the file
      String? originalFileName;
      String? originalFilePath;
      if (widget.projectData['subtitleCollection'] != null) {
        final subtitleData = widget.projectData['subtitleCollection'] as Map<String, dynamic>;
        originalFileName = subtitleData['fileName'];
        originalFilePath = subtitleData['filePath'] ?? subtitleData['originalFileUri'];
      }

      // Get existing session's file path information if available
      String? existingFileName;
      String? existingFilePath;
      if (existingSession != null) {
        final existingSubtitle = await ref
            .read(sessionProjectImportRepositoryProvider)
            .getSubtitleCollection(existingSession.subtitleCollectionId);
        if (existingSubtitle != null) {
          existingFileName = existingSubtitle.fileName;
          existingFilePath = existingSubtitle.filePath ?? existingSubtitle.originalFileUri;
        }
      }
      
      // Show a custom sheet explaining why we need to select the SRT file
      final choice = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return _LocateSrtSheet(
            originalFileName: originalFileName,
            originalFilePath: originalFilePath,
            existingFileName: existingFileName,
            existingFilePath: existingFilePath,
          );
        },
      );

      if (choice == null || choice == 'cancel') {
        return null;
      } else if (choice == 'use_existing_project') {
        // User chose to use the existing project's path - no need to update file paths in database
        if (existingFilePath != null && existingFileName != null) {
          return {
            'filePath': null, // No file path update needed
            'fileName': existingFileName,
            'safUri': null, // No URI update needed
            'fileUri': null, // No file reference update needed - keep existing
            'useExistingProject': 'true', // Flag to indicate using existing project's paths
          };
        } else {
          if (mounted) {
            SnackbarHelper.showError(context, 'Existing project file path not available');
          }
          return null;
        }
      } else if (choice == 'use_importing_file') {
        // User chose to use the importing file's path - no need to update file paths in database
        if (originalFilePath != null && originalFileName != null) {
          return {
            'filePath': null, // No file path update needed
            'fileName': originalFileName,
            'safUri': null, // No URI update needed
            'fileUri': null, // No file reference update needed - keep existing
            'useImportingFile': 'true', // Flag to indicate using importing file's paths
          };
        } else {
          if (mounted) {
            SnackbarHelper.showError(context, 'Importing file path not available');
          }
          return null;
        }
      } else if (choice == 'select_new') {
        // User chose to create a new SRT file in a selected folder
        return await _createSrtFile();
      }
      
      return null;
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not select the subtitle file. Please try again.');
      }
      return null;
    }
  }

  /// Create a new SRT file in the selected folder
  Future<Map<String, String?>?> _createSrtFile() async {
    try {
      // Get the subtitle lines from project data
      final subtitleCollectionData = widget.projectData['subtitleCollection'] as Map<String, dynamic>;
      final linesData = subtitleCollectionData['lines'] as List<dynamic>;
      
      // Convert to SubtitleLine objects
      List<SubtitleLine> subtitleLines = linesData.map((lineData) {
        final data = Map<String, dynamic>.from(lineData);
        return SubtitleLine()
          ..index = data['index'] ?? 0
          ..startTime = data['startTime'] ?? '00:00:00,000'
          ..endTime = data['endTime'] ?? '00:00:02,000'
          ..original = data['original'] ?? ''
          ..edited = data['edited']
          ..marked = data['marked'] ?? false;
      }).toList();
      
      // Generate SRT content
      final srtContent = SrtCompiler.generateSrtContent(subtitleLines);
      
      // Get original filename for the SRT file
      String originalFileName = subtitleCollectionData['fileName'] ?? '';
      if (originalFileName.isEmpty) {
        // Fallback to session fileName if subtitle fileName is not available
        final sessionData = widget.projectData['session'] as Map<String, dynamic>;
        originalFileName = sessionData['fileName'] ?? 'subtitle';
      }
      
      // Ensure .srt extension
      if (!originalFileName.toLowerCase().endsWith('.srt')) {
        originalFileName = '$originalFileName.srt';
      }
      
      if (Platform.isAndroid) {
        // On Android, use SAF to save the file and get proper URI
        try {
          final fileInfo = await PlatformFileHandler.saveNewFile(
            content: srtContent,
            fileName: originalFileName,
            mimeType: 'application/x-subrip',
          );
          
          if (fileInfo != null) {
            return {
              'filePath': fileInfo.path, // Display path for UI
              'fileName': originalFileName,
              'safUri': fileInfo.safUri, // This is the proper SAF URI
              'fileUri': fileInfo.safUri ?? fileInfo.path, // Prefer SAF URI
            };
          }
        } catch (e) {
          if (mounted) {
            SnackbarHelper.showError(context, 'Could not create the subtitle file. Please try again.');
          }
          return null;
        }
      } else {
        // On desktop, select a folder and save the file traditionally
        final selectedFolder = await FilePickerConvenience.pickExportFolder(context: context);
        
        if (selectedFolder != null) {
          final filePath = path.join(selectedFolder, originalFileName);
          final file = File(filePath);
          
          // Write the file
          await file.writeAsString(srtContent);
          
          return {
            'filePath': filePath,
            'fileName': originalFileName,
            'safUri': null,
            'fileUri': filePath,
          };
        }
      }
      
      return null;
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not create the subtitle file. Please try again.');
      }
      return null;
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ref
          .read(sessionProjectImportRepositoryProvider)
          .fetchSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SnackbarHelper.showError(
        context,
        'Could not load your sessions. Please try again.',
      );
    }
  }

  Future<void> _replaceSession(Session session) async {
    setState(() {
      _isReplacing = true;
      _selectedSession = session;
    });

    try {
      // Ask user to select the SRT file location since it may be different on each device
      final srtFileInfo = await _selectSrtFilePath(existingSession: session);
      if (srtFileInfo == null) {
        // User cancelled the selection
        setState(() {
          _isReplacing = false;
          _selectedSession = null;
        });
        return;
      }

      final updatedSession = await ref
          .read(sessionProjectImportRepositoryProvider)
          .replaceSession(
            session: session,
            projectData: widget.projectData,
            srtFileInfo: srtFileInfo,
            originalProjectUri: widget.originalFileUri,
          );

        if (mounted) {
          SnackbarHelper.showSuccess(
            context,
            'Session "${updatedSession.fileName}" updated successfully!',
            duration: const Duration(seconds: 3),
          );
          
          // Callback to parent widget first
          if (widget.onSessionReplaced != null) {
            widget.onSessionReplaced!(updatedSession);
          }
          
          // Callback to refresh home screen sessions
          if (widget.onProjectImported != null) {
            widget.onProjectImported!(updatedSession);
          }
          
          // Navigate to EditScreen with the updated session
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => EditScreenHost(
                subtitleCollectionId: updatedSession.subtitleCollectionId,
                sessionId: updatedSession.id,
                lastEditedIndex: updatedSession.lastEditedIndex,
              ),
            ),
            (route) => route.isFirst, // Remove all routes except the first one
          );
        }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not replace the selected session. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReplacing = false;
          _selectedSession = null;
        });
      }
    }
  }

  Future<void> _importAsNewSession() async {
    setState(() {
      _isCreating = true;
    });

    try {
      // Ask user to select the SRT file location since it may be different on each device
      final srtFileInfo = await _selectSrtFilePath(); // No existing session when importing as new
      if (srtFileInfo == null) {
        // User cancelled the selection
        setState(() {
          _isCreating = false;
        });
        return;
      }

      final createdSession = await ref
          .read(sessionProjectImportRepositoryProvider)
          .importAsNewSession(
            projectData: widget.projectData,
            srtFileInfo: srtFileInfo,
            originalProjectUri: widget.originalFileUri,
          );

      if (mounted) {
        SnackbarHelper.showSuccess(
          context,
          'Project imported as new session successfully!',
          duration: const Duration(seconds: 3),
        );
        
        // Callback to parent widget first
        if (widget.onSessionCreated != null) {
          widget.onSessionCreated!(createdSession);
        }
        
        // Callback to refresh home screen sessions
        if (widget.onProjectImported != null) {
          widget.onProjectImported!(createdSession);
        }
        
        // Navigate to EditScreen with the new session
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => EditScreenHost(
              subtitleCollectionId: createdSession.subtitleCollectionId,
              sessionId: createdSession.id,
              lastEditedIndex: createdSession.lastEditedIndex,
            ),
          ),
          (route) => route.isFirst, // Remove all routes except the first one
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not import the project as a new session. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  /// Build session item widget
  Widget _buildSessionItem(Session session) {
    final primaryColor = Theme.of(context).primaryColor;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);
    final isSelected = _selectedSession?.id == session.id;
    final isLoading = _isReplacing && isSelected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _replaceSession(session),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected && isLoading 
                  ? primaryColor.withValues(alpha: 0.1)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.subtitles,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.fileName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 14,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.editMode ? 'Edit Mode' : 'Translation Mode',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (session.lastEditedIndex != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.bookmark,
                              size: 14,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Line ${session.lastEditedIndex! + 1}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          if (ProjectManager.hasProjectFile(session)) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.folder,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Project',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onSurfaceColor.withValues(alpha: 0.3),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final mutedColor = onSurfaceColor.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.file_download,
                      color: primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Project',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Replace an existing session or import as new',
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

            const SizedBox(height: 16),

            // Sessions List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )
            else if (_sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: mutedColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sessions found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a session first to replace it with imported data',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ..._sessions.map((session) => _buildSessionItem(session)),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: Container(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: (_isReplacing || _isCreating) ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurfaceColor,
                        side: BorderSide(
                          color: onSurfaceColor.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close,
                            size: 20,
                            color: onSurfaceColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: onSurfaceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Import as New Button
                Expanded(
                  child: Container(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isReplacing || _isCreating) ? null : _importAsNewSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Import as New',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
