part of '../../screen_edit.dart';

extension _EditProjectActions on _EditScreenState {
  Future<void> _handleSave() async {
    try {
      if (_isSourceView) {
        await _syncSourceViewToDatabase();
      }

      final subtitleCollection = await _controller.loadSubtitleCollection();
      if (subtitleCollection == null) {
        if (mounted) SnackbarHelper.showError(context, 'Failed to load subtitle data');
        return;
      }

      final currentLines = await _controller.loadSubtitleLines();
      // Shared, strict encoding and file-access policy. Neither the Widget
      // nor this UI extension writes bytes to platform files directly.
      final EditorDirectSaveResult result;
      try {
        result = await ref.read(editorDirectSaveServiceProvider)
            .save(subtitleCollection, currentLines);
      } on FormatException {
        if (mounted) SnackbarHelper.showError(context,
            'Subtitle text cannot be saved with this encoding. '
            'Choose a compatible encoding in Project Settings.');
        return;
      } on UnsupportedError {
        if (mounted) SnackbarHelper.showError(context,
            'The selected encoding is unavailable on this device. '
            'Choose a compatible encoding in Project Settings.');
        return;
      }

      if (!mounted) return;
      if (result.saved) {
        final legacyPath = result.legacyFilePathToPersist;
        if (legacyPath != null && legacyPath.isNotEmpty) {
          // Preserve the existing legacy project migration through its typed
          // repository, never through an old mutable Isar object.
          await _controller.updateOriginalFileUri(legacyPath);
          if (!mounted) return;
        }
        if (mounted) SnackbarHelper.showSuccess(context, 'File saved successfully!');
        return;
      }
      
      // Fallback to "Save As"
      await _handleSaveFileAs();

    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Could not save the subtitle file. Please try again.');
    }
  }

  Future<void> _handleSaveFileAs() async {
    try {
      final subtitle = await _controller.loadSubtitleCollection();

      if (subtitle == null) {
        throw Exception('Could not find subtitle with ID: ${widget.subtitleCollectionId}');
      }

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
          ),
          builder: (context) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ExportBottomSheet(
                subtitle: subtitle,
                onExportComplete: () {
                  SnackbarHelper.showSuccess(context, 'Export completed successfully!', duration: const Duration(seconds: 1));
                },
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not prepare the export. Please try again.');
      }
    }
  }

  Future<void> _handleSaveProject() async {
    try {
      // Get current session and subtitle collection
      final session = await _controller.loadSession();
      final subtitleCollection = await _controller.loadSubtitleCollection();
      
      if (session == null || subtitleCollection == null) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Failed to load session data');
        }
        return;
      }

      if (context.mounted) {
        final projectPath = await ProjectSaveFlow.save(
          context: context,
          coordinator: ref.read(projectSaveCoordinatorProvider),
          session: session,
          subtitleCollection: subtitleCollection,
        );

        if (projectPath != null) {
          // Update the session with the project file path
          await ref.read(projectRepositoryProvider).updateSessionProjectPath(
                sessionId: widget.sessionId,
                projectFilePath: projectPath,
              );
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Could not save the project. Please try again.');
      }
    }
  }

  Future<void> _showProjectSettings() async {
    if (context.mounted) {
      // Fetch the current session and subtitle collection
      final session = await _controller.loadSession();
      final subtitleCollection = await _controller.loadSubtitleCollection();
      
      if (session != null && subtitleCollection != null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 1.0, // Make fullscreen
            minChildSize: 1.0,
            maxChildSize: 1.0,
            builder: (context, scrollController) => ProjectSettingsSheet(
              session: session,
              subtitleCollection: subtitleCollection,
              onProjectUpdated: () {
                // Refresh the current view if needed
                _setEditorState(() {});
              },
              onSecondarySubtitlesLoaded: (secondarySubtitles) {
                _controller.setSecondarySubtitlesLocally(secondarySubtitles);
                _videoPlayerKey.currentState
                    ?.updateSecondarySubtitles(_secondarySubtitles);
                SnackbarHelper.showSuccess(
                  context,
                  'Secondary subtitles loaded',
                );
              },
              onSecondarySubtitlesCleared: () {
                _controller.clearSecondarySubtitlesLocally();
                _videoPlayerKey.currentState
                    ?.updateSecondarySubtitles(const []);
                SnackbarHelper.showSuccess(
                  context,
                  'Secondary subtitles cleared',
                );
              },
              onSaveProject: _handleSaveProject,
              onLoadVideo: _pickVideoFile,
            ),
          ),
        );
      } else {
        SnackbarHelper.showSnackBar(
          context,
          'Error: Could not load project data',
          backgroundColor: Colors.red,
        );
      }
    }
  }
}
