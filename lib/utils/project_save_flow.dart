import 'dart:io';

import 'package:flutter/material.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/services/project_save_coordinator.dart';
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';

/// Presentation-layer save flow for .msone projects.
///
/// This owns user interaction such as folder selection and success feedback.
/// Project document construction and persistence remain in
/// [ProjectSaveCoordinator].
class ProjectSaveFlow {
  const ProjectSaveFlow._();

  static Future<String?> save({
    required BuildContext context,
    required ProjectSaveCoordinator coordinator,
    required Session session,
    required SubtitleCollection subtitleCollection,
    bool forceNewLocation = false,
    String? suggestedFileName,
    bool showSuccessMessage = true,
  }) async {
    if (!forceNewLocation &&
        session.projectFilePath != null &&
        session.projectFilePath!.isNotEmpty) {
      final updated = await coordinator.updateExisting(
        session: session,
        subtitleCollection: subtitleCollection,
      );

      if (updated) {
        if (showSuccessMessage && context.mounted) {
          SnackbarHelper.showSuccess(
            context,
            'Project saved successfully!',
          );
        }
        return session.projectFilePath;
      }
    }

    String? projectPath;

    if (Platform.isAndroid) {
      projectPath = await coordinator.saveAndroidNew(
        session: session,
        subtitleCollection: subtitleCollection,
        suggestedFileName: suggestedFileName,
      );
    } else if (Platform.isIOS) {
      projectPath = await coordinator.saveIosNew(
        session: session,
        subtitleCollection: subtitleCollection,
        suggestedFileName: suggestedFileName,
      );
    } else {
      final directoryPath = await FilePickerConvenience.pickExportFolder(
        context: context,
      );
      if (directoryPath == null) return null;

      projectPath = await coordinator.saveDesktopNew(
        session: session,
        subtitleCollection: subtitleCollection,
        directoryPath: directoryPath,
        suggestedFileName: suggestedFileName,
      );
    }

    if (projectPath != null &&
        showSuccessMessage &&
        context.mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Project saved successfully!',
      );
    }

    return projectPath;
  }
}
