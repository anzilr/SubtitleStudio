import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';
import 'package:subtitle_studio/widgets/session_selection_sheet.dart';
import 'package:subtitle_studio/services/checkpoint_repository.dart';
import 'package:subtitle_studio/services/project_document_codec.dart';
import 'package:subtitle_studio/services/project_document_builder.dart';
import 'package:subtitle_studio/services/project_file_service.dart';

/// Project Manager for .msone files
/// 
/// This class handles all operations related to .msone project files:
/// - Auto-saving projects when importing/creating subtitles
/// - Manual project saving with user-selected locations
/// - Loading and updating existing projects
/// - Managing project metadata and versioning
class ProjectManager {
  static const String projectVersion = '2.0';
  
  /// Auto-save project file after importing/creating subtitles
  /// This is called automatically when new content is imported
  static Future<String?> autoSaveProject({
    required BuildContext context,
    required CheckpointRepository checkpointRepository,
    required Session session,
    required SubtitleCollection subtitleCollection,
    String? suggestedFileName,
  }) async {
    try {
      final projectData = await _createProjectData(
        session,
        subtitleCollection,
        checkpointRepository,
      );
      final fileName = (suggestedFileName ?? session.fileName)
          .replaceAll(RegExp(r'\.[^.]*$'), '') + '.msone';
      
      if (Platform.isAndroid) {
        return await _saveProjectWithSAF(
          context: context,
          projectDocument: projectDocument,
          fileName: fileName,
        );
      } else if (Platform.isIOS) {
        return await _saveProjectWithFilePicker(
          context: context,
          projectData: projectData,
          fileName: fileName,
        );
      } else {
        return await _saveProjectWithPicker(
          context: context,
          projectData: projectData,
          fileName: fileName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Auto-save project error: $e');
      }
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to save project: $e');
      }
      return null;
    }
  }
  
  /// Save project to existing location or prompt for new location
  static Future<String?> saveProject({
    required BuildContext context,
    required CheckpointRepository checkpointRepository,
    required Session session,
    required SubtitleCollection subtitleCollection,
    bool forceNewLocation = false,
  }) async {
    try {
      final projectData = await _createProjectData(
        session,
        subtitleCollection,
        checkpointRepository,
      );
      
      // If we have an existing project file path and not forcing new location
      if (!forceNewLocation && session.projectFilePath != null) {
        final success = await _updateExistingProject(
          projectFilePath: session.projectFilePath!,
          projectData: projectData,
        );
        
        if (success) {
          if (context.mounted) {
            SnackbarHelper.showSuccess(context, 'Project saved successfully!');
          }
          return session.projectFilePath;
        }
      }
      
      // Save to new location
      final fileName = session.fileName
          .replaceAll(RegExp(r'\.[^.]*$'), '') + '.msone';
      
      if (Platform.isAndroid) {
        return await _saveProjectWithSAF(
          context: context,
          projectData: projectData,
          fileName: fileName,
        );
      } else if (Platform.isIOS) {
        return await _saveProjectWithFilePicker(
          context: context,
          projectData: projectData,
          fileName: fileName,
        );
      } else {
        return await _saveProjectWithPicker(
          context: context,
          projectData: projectData,
          fileName: fileName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Save project error: $e');
      }
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to save project: $e');
      }
      return null;
    }
  }
  
  /// Create project data structure for .msone file
  static Future<ProjectDocument> _createProjectData(
    Session session,
    SubtitleCollection subtitleCollection,
    CheckpointRepository checkpointRepository,
  ) async {
    final checkpoints = await _fetchCheckpoints(
      session.id,
      checkpointRepository,
    );

    return ProjectDocumentBuilder.build(
      session: session,
      subtitleCollection: subtitleCollection,
      checkpoints: checkpoints,
      projectVersion: projectVersion,
      appVersion: '3.0.0',
    );
  }

  static Future<List<Checkpoint>> _fetchCheckpoints(
    int sessionId,
    CheckpointRepository checkpointRepository,
  ) async {
    try {
      final checkpoints =
          await checkpointRepository.getCheckpointsForSession(sessionId);

      if (kDebugMode) {
        debugPrint(
          '[ProjectManager] Loaded ${checkpoints.length} checkpoints '
          'for project serialization',
        );
      }

      return checkpoints;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProjectManager] Error fetching checkpoints: $e');
      }
      return const [];
    }
  }

  /// Save project using SAF (Android)
  static Future<String?> _saveProjectWithSAF({
    required BuildContext context,
    required ProjectDocument projectData,
    required String fileName,
  }) async {
    final result = await ProjectFileService.saveAndroidProject(
      content: ProjectDocumentCodec.encode(projectData),
      fileName: fileName,
    );

    if (result != null && context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Project saved successfully!',
        duration: const Duration(seconds: 2),
      );
    }

    return result;
  }

  /// Save project using the iOS document picker.
  static Future<String?> _saveProjectWithFilePicker({
    required BuildContext context,
    required ProjectDocument projectData,
    required String fileName,
  }) async {
    final result = await ProjectFileService.saveIosProject(
      content: ProjectDocumentCodec.encode(projectData),
      fileName: fileName,
    );

    if (result != null && context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Project saved successfully!',
        duration: const Duration(seconds: 2),
      );
    }

    return result;
  }

  /// Save project using a user-selected desktop directory.
  static Future<String?> _saveProjectWithPicker({
    required BuildContext context,
    required ProjectDocument projectData,
    required String fileName,
  }) async {
    final selectedPath = await FilePickerConvenience.pickExportFolder(
      context: context,
    );
    if (selectedPath == null) return null;

    final filePath = await ProjectFileService.saveDesktopProject(
      content: ProjectDocumentCodec.encode(projectData),
      directoryPath: selectedPath,
      fileName: fileName,
    );

    if (context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Project saved to: $filePath',
        duration: const Duration(seconds: 3),
      );
    }

    return filePath;
  }

  /// Update an existing project file when the platform grants durable access.
  static Future<bool> _updateExistingProject({
    required String projectFilePath,
    required ProjectDocument projectData,
  }) async {
    try {
      return await ProjectFileService.updateExistingProject(
        content: ProjectDocumentCodec.encode(projectData),
        projectFilePath: projectFilePath,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update existing project error: $e');
      }
      return false;
    }
  }

  /// Check if session has an associated project file
  static bool hasProjectFile(Session session) {
    return session.projectFilePath != null && 
           session.projectFilePath!.isNotEmpty;
  }
  
  /// Get user-friendly project file name
  static String getProjectFileName(Session session) {
    if (!hasProjectFile(session)) return 'Untitled Project';
    
    final path = session.projectFilePath!;
    if (Platform.isAndroid && path.startsWith('content://')) {
      // Extract filename from SAF URI (this might need refinement)
      return '${session.fileName.replaceAll(RegExp(r'\.[^.]*$'), '')}.msone';
    } else {
      return path.split(Platform.pathSeparator).last;
    }
  }
  
  /// Show session selection sheet for replacing import data or importing as new
  static Future<Session?> showSessionSelectionSheet({
    required BuildContext context,
    required ProjectDocument projectDocument,
    String? originalFileUri,
    Function(Session)? onProjectImported,
  }) async {
    Session? resultSession;
    
    await showModalBottomSheet<Session>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SessionSelectionSheet(
          projectData: projectData,
          originalFileUri: originalFileUri,
          onSessionReplaced: (session) {
            resultSession = session;
          },
          onSessionCreated: (session) {
            resultSession = session;
          },
          onProjectImported: onProjectImported,
        );
      },
    );
    
    return resultSession;
  }
}

/// Actions for importing project files
enum ImportAction {
  importAsNew,
  cancel,
}
