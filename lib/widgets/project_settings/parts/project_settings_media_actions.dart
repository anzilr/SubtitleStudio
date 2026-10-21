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
      // URI-only on Android: reading an entire MKV here can exhaust memory.
      // The legacy SAF display path is never a usable video storage locator.
      final videoPath = await FilePickerConvenience.pickVideoFile(
        context: context,
      );

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
        _setProjectSettingsState(() {
          _videoPath = savedPath;
        });
        if (kDebugMode) {
          debugPrint('Project Settings: video source ${savedPath == null ? 'not set' : 'loaded'}');
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
          filePath = fileInfo.pickedReference.accessLocator;
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
        
        if (filePath == null) return; // Picker cancelled.
        final file = File(filePath);
        fileContent = await file.readAsString();
        fileName = file.path.split(Platform.pathSeparator).last;
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
          widget.onSecondarySubtitlesLoaded?.call(
            parsedSubtitles,
            fromOriginal: false,
          );
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
    final originalTextSubtitles = EditorSecondarySubtitleService.fromOriginal(
      widget.subtitleCollection.lines,
    );

    if (originalTextSubtitles.isNotEmpty) {
      widget.onSecondarySubtitlesLoaded?.call(
        originalTextSubtitles,
        fromOriginal: true,
      );
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
    // Persist first; do not falsely show a new selection if the database
    // rejects the update. Never save an unverified native codec label.
    if (_encodingSaveInProgress ||
        _encodingsLoading ||
        !_availableEncodings.contains(encoding) ||
        encoding == _selectedEncoding) {
      return;
    }

    _setProjectSettingsState(() => _encodingSaveInProgress = true);
    try {
      final updated = await ref
          .read(subtitleRepositoryProvider)
          .updateEncoding(
            collectionId: widget.subtitleCollection.id,
            sessionId: widget.session.id,
            encoding: encoding,
          );
      if (!updated) {
        throw StateError('Encoding metadata could not be saved.');
      }

      widget.subtitleCollection.encoding = encoding;
      if (!mounted) return;
      _setProjectSettingsState(() => _selectedEncoding = encoding);
      SnackbarHelper.showSnackBar(
        context,
        'Encoding updated to $encoding',
        backgroundColor: Colors.green,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Project Settings failed to update encoding: $error');
      }
      if (!mounted) return;
      SnackbarHelper.showSnackBar(
        context,
        'Could not update the text encoding. Please try again.',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        _setProjectSettingsState(() => _encodingSaveInProgress = false);
      }
    }
  }

}
