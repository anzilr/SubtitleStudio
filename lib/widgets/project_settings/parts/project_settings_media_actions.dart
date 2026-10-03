part of '../../project_settings_sheet.dart';

extension _ProjectSettingsMediaActions on _ProjectSettingsSheetState {
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

      await ref.read(editorPreferencesRepositoryProvider).saveVideoPath(
        widget.session.subtitleCollectionId,
        videoPath,
      );
      if (!mounted) return;

      _setProjectSettingsState(() {
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
      final savedPath = await ref
          .read(editorPreferencesRepositoryProvider)
          .getVideoPath(widget.session.subtitleCollectionId);
      if (mounted) {
        final oldPath = _videoPath;
        _setProjectSettingsState(() {
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
    await ref
        .read(editorPreferencesRepositoryProvider)
        .removeVideoPath(widget.session.subtitleCollectionId);
    _setProjectSettingsState(() {
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
          await ref.read(editorPreferencesRepositoryProvider).saveSecondarySubtitlePath(
            widget.session.subtitleCollectionId,
            filePath,
          );
          await ref.read(editorPreferencesRepositoryProvider).setSecondaryIsOriginal(
            widget.session.subtitleCollectionId,
            false,
          );
          
          _setProjectSettingsState(() {
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
      await ref.read(editorPreferencesRepositoryProvider).setSecondaryIsOriginal(
        widget.session.subtitleCollectionId,
        true,
      );
      await ref.read(editorPreferencesRepositoryProvider).removeSecondarySubtitlePath(
        widget.session.subtitleCollectionId,
      );
      
      _setProjectSettingsState(() {
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
    await ref.read(editorPreferencesRepositoryProvider).removeSecondarySubtitlePath(
        widget.session.subtitleCollectionId,
      );
    await ref.read(editorPreferencesRepositoryProvider).setSecondaryIsOriginal(
        widget.session.subtitleCollectionId,
        false,
      );
    
    _setProjectSettingsState(() {
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
      await ref
          .read(subtitleRepositoryProvider)
          .updateCollection(widget.subtitleCollection);
      
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

}
