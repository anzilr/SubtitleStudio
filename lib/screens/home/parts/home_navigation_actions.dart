part of '../../screen_home.dart';

extension _HomeNavigationActions on _HomeScreenContentState {
  Future<void> _navigateToEditScreen(Session session) async {
    try {
      await ref
          .read(homeControllerProvider.notifier)
          .updateLastEditedSession(session.id);
  
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditScreenHost(
            subtitleCollectionId: session.subtitleCollectionId,
            lastEditedIndex: session.lastEditedIndex,
            sessionId: session.id,
          ),
        ),
      );
  
      if (mounted) {
        await _reRegisterHomeScreenShortcuts();
        ref.read(homeControllerProvider.notifier).loadSessions();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Navigation error: $e');
      }
      if (mounted) {
        ref.read(homeControllerProvider.notifier).loadSessions();
      }
    }
  }
  
  Future<void> _handleCreate() async {
    try {
      if (!mounted) return;
  
      final controller = ref.read(homeControllerProvider.notifier);
  
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
        ),
        builder: (context) => CreateSubtitleSheet(
          onSubtitleCreated: (subtitleData) async {
            if (subtitleData == null) return;
  
            controller.loadSessions();
  
            final createdSessionId = subtitleData.sessionId;
            await controller.updateLastEditedSession(createdSessionId);
  
            if (mounted) {
              final navigator = Navigator.of(context);
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => EditSubtitleScreenHost(
                    subtitleId: subtitleData.subtitleCollectionId,
                    index: 1,
                    sessionId: createdSessionId,
                    isNewSubtitle: true,
                    editMode: subtitleData.editMode,
                  ),
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Something went wrong. Please try again.');
    }
  }
  
  void _handleImport() {
    // Capture cubit reference before opening bottom sheet
    final controller = ref.read(homeControllerProvider.notifier);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SubtitleImportOptionsSheet(
        onSubtitleImported: (session) {
          controller.loadSessions();
          _navigateToEditScreen(session);
        },
      ),
    );
  }
  
  void _showImportWithFilePath(String filePath, String? fileName, {String? originalSafUri}) {
    // Capture cubit reference before opening bottom sheet
    final controller = ref.read(homeControllerProvider.notifier);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SubtitleImportOptionsSheet(
        initialFilePath: filePath,
        initialFileName: fileName,
        originalSafUri: originalSafUri,  // Pass original SAF URI
        onSubtitleImported: (session) {
          controller.loadSessions();
          _navigateToEditScreen(session);
        },
      ),
    );
  }
  
  void _handleExtract() {
    // Capture cubit reference before opening bottom sheet
    final controller = ref.read(homeControllerProvider.notifier);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SubtitleExtractOptionsSheet(
        onSubtitleExtracted: (session) async {
          try {
            await controller.updateLastEditedSession(session.id);
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (mounted) {
              await controller.loadSessions();
              _navigateToEditScreen(session);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error during extraction navigation: $e');
            }
            if (mounted) {
              SnackbarHelper.showError(context, 'Something went wrong. Please try again.');
            }
          }
        },
      ),
    );
  }
  
  void _handleImportProject({String? preselectedFilePath, String? originalSafUri}) {
    // Capture cubit reference before opening bottom sheet
    final controller = ref.read(homeControllerProvider.notifier);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ImportProjectSheet(
        initialFilePath: preselectedFilePath,
        originalSafUri: originalSafUri,  // Pass original SAF URI
        onProjectImported: (session) async {
          try {
            await controller.updateLastEditedSession(session.id);
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (mounted) {
              await controller.loadSessions();
              // Navigation is now handled by SessionSelectionSheet
              // No need to navigate here as it would cause duplicate navigation
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error during import navigation: $e');
            }
            if (mounted) {
              SnackbarHelper.showError(context, 'Something went wrong. Please try again.');
            }
          }
        },
      ),
    );
  }
  
  void _handleSourceView() async {
    try {
      // Check if SAF is available (Android)
      if (SafFileHandler.isAvailable) {
        // Use SAF file picker for Android
        final fileInfo = await SafFileHandler.openFile(
          mimeTypes: ['text/plain', 'application/x-subrip', '*/*'],
        );
        
        if (fileInfo != null && mounted) {
          // Fix the display path using proper SAF URI conversion
          final correctedPath = SafPathConverter.normalizePath(fileInfo.uri);
          
          if (kDebugMode) {
            print('Home _handleSourceView: originalPath=${fileInfo.displayPath}, correctedPath=$correctedPath, uri=${fileInfo.uri}');
          }
          
          // Load file content from URI (openFile now returns URI-only for memory safety)
          String? fileContent;
          try {
            final contentBytes = await SafFileHandler.readFileFromUri(fileInfo.uri);
            try {
              fileContent = utf8.decode(contentBytes);
            } catch (e) {
              // If UTF-8 fails, try Latin-1 as fallback
              try {
                fileContent = latin1.decode(contentBytes);
              } catch (e2) {
                if (kDebugMode) {
                  print('Failed to decode file content: $e2');
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to read file content: $e');
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to read file: ${e.toString()}')),
              );
            }
            return;
          }
          
          // Navigate to source view screen with SAF URI and pre-loaded content
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SourceViewScreen(
                filePath: correctedPath, // Use corrected path
                displayName: fileInfo.fileName,
                safUri: fileInfo.uri,
                fileContent: fileContent, // Pass pre-loaded content
              ),
            ),
          ).then((_) {
            // Re-register shortcuts when returning from source view
            _reRegisterHomeScreenShortcuts();
          });
        }
      } else {
        // Use regular file picker for non-Android platforms
        final filePath = await FilePickerConvenience.pickSubtitleFile(context: context);
        
        if (filePath != null && mounted) {
          // Navigate to source view screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SourceViewScreen(
                filePath: filePath,
              ),
            ),
          ).then((_) {
            // Re-register shortcuts when returning from source view
            _reRegisterHomeScreenShortcuts();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open this file. Please verify the file and try again.');
      }
      await logError('Error in source view handler: $e');
    }
  }
}
