part of '../../screen_edit.dart';

extension _EditProjectActions on _EditScreenState {
  Future<void> _handleSave() async {
    try {
      if (_isSourceView) {
        await _syncSourceViewToDatabase();
      }

      final subtitleCollection = await isar.subtitleCollections.get(widget.subtitleCollectionId);
      if (subtitleCollection == null) {
        if (mounted) SnackbarHelper.showError(context, 'Failed to load subtitle data');
        return;
      }

      final currentLines = await fetchSubtitleLines(widget.subtitleCollectionId);
      final srtContent = SrtCompiler.generateSrtContent(currentLines);
      bool saveSuccessful = false;

      // Attempt to save directly
      try {
        if (Platform.isMacOS) {
          final srtBookmark = subtitleCollection.macOsSrtBookmark;
          if (srtBookmark != null) {
            String? srtPath;
            try {
              srtPath = await MacOSBookmarkManager.resolveBookmark(base64Decode(srtBookmark));
              await File(srtPath!).writeAsString(srtContent);
              saveSuccessful = true;
                        } finally {
              if (srtPath != null) {
                await MacOSBookmarkManager.stopAccessingSecurityScopedResource(srtPath);
              }
            }
          }
        } else {
          // Try originalFileUri first, fall back to filePath for older entries
          String? originalFileUri = subtitleCollection.originalFileUri;
          String? filePath = subtitleCollection.filePath;
          
          // Use originalFileUri if available, otherwise fall back to filePath
          String? targetPath = (originalFileUri!.isNotEmpty) 
              ? originalFileUri 
              : filePath;
          
          if (targetPath!.isNotEmpty) {
            print('Attempting to save to: $targetPath');
            if (await PlatformFileHandler.writeFile(
              content: srtContent,
              filePath: targetPath,
              fileName: subtitleCollection.fileName,
              mimeType: 'application/x-subrip',
            )) {
              saveSuccessful = true;
              print('Save successful to: $targetPath');
              
              // Update originalFileUri if it wasn't set (for older entries)
              if (originalFileUri.isEmpty) {
                subtitleCollection.originalFileUri = targetPath;
                await updateSubtitleCollection(subtitleCollection);
                print('Updated originalFileUri to: $targetPath');
              }
            } else {
              print('PlatformFileHandler.writeFile returned false for: $targetPath');
            }
          } else {
            print('No valid file path found (originalFileUri and filePath are both empty)');
          }
        }
      } catch (e) {
        print('Direct save failed: $e');
        print('Stack trace: ${StackTrace.current}');
      }

      if (saveSuccessful) {
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
      final subtitle = await fetchSubtitle(widget.subtitleCollectionId);

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
      final session = await isar.sessions.get(widget.sessionId);
      final subtitleCollection = await isar.subtitleCollections.get(widget.subtitleCollectionId);
      
      if (session == null || subtitleCollection == null) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Failed to load session data');
        }
        return;
      }

      if (context.mounted) {
        final projectPath = await ProjectManager.saveProject(
          context: context,
          session: session,
          subtitleCollection: subtitleCollection,
        );

        if (projectPath != null) {
          // Update the session with the project file path
          await ProjectManager.updateSessionProjectPath(
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
      final session = await isar.sessions.get(widget.sessionId);
      final subtitleCollection = await isar.subtitleCollections.get(widget.subtitleCollectionId);
      
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
                _setEditorState(() {
                  _originalSecondarySubtitles = secondarySubtitles;
                  _secondarySubtitles = _generateSimpleSubtitles(secondarySubtitles);
                  if (_videoPlayerKey.currentState != null) {
                    _videoPlayerKey.currentState!.updateSecondarySubtitles(_secondarySubtitles);
                  }
                });
                SnackbarHelper.showSuccess(context, 'Secondary subtitles loaded');
              },
              onSecondarySubtitlesCleared: () {
                _setEditorState(() {
                  _originalSecondarySubtitles = [];
                  _secondarySubtitles = [];
                  if (_videoPlayerKey.currentState != null) {
                    _videoPlayerKey.currentState!.updateSecondarySubtitles(_secondarySubtitles);
                  }
                });
                SnackbarHelper.showSuccess(context, 'Secondary subtitles cleared');
              },
              onSaveProject: () {
                _handleSaveProject();
              },
              onLoadVideo: () {
                // Use the EditScreen's video loading function
                _pickVideoFile();
              },
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
