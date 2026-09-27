part of '../video_player_widget.dart';

extension _VideoSubtitlePreferences on VideoPlayerWidgetState {
  Future<void> _loadSubtitlePreferences() async {
    try {
      final savedSize = await PreferencesModel.getSubtitleFontSize();
      final savedPath = await PreferencesModel.getSubtitleFontPath();
      final skipDuration = await PreferencesModel.getSkipDurationSeconds();
      final primaryPosition = await PreferencesModel.getPrimarySubtitleVerticalPosition();
      final secondaryPosition = await PreferencesModel.getSecondarySubtitleVerticalPosition();
      final savedVolume = await PreferencesModel.getVideoVolume();
      final showBackground = await PreferencesModel.getShowSubtitleBackground();
      _setVideoState(() {
        _subtitleFontSize = savedSize;
        _skipDurationSeconds = skipDuration;
        _primarySubtitleVerticalPosition = primaryPosition;
        _secondarySubtitleVerticalPosition = secondaryPosition;
        _currentVolume = savedVolume;
        _showSubtitleBackground = showBackground;
      });
      if (savedPath != null) {
        // If file exists at saved path, attempt to load it, else clear pref
        final f = File(savedPath);
        if (await f.exists()) {
          await _loadFontFromFile(f);
        } else {
          await PreferencesModel.setSubtitleFontPath(null);
        }
      }
    } catch (e) {
      // ignore errors and keep defaults
    }
  }
  
  Future<void> _loadFontFromFile(File file) async {
    try {
      final fileName = file.uri.pathSegments.last;
      final family = 'CustomSubtitleFont_${fileName.hashCode}';
  
      final bytes = await file.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
  
      _setVideoState(() {
        _subtitleFontFamily = family;
        _subtitleFontFilePath = file.path;
      });
      await PreferencesModel.setSubtitleFontPath(file.path);
      // Rebuild any custom fullscreen overlay if present
      _fullscreenOverlay?.markNeedsBuild();
    } catch (e) {
      // ignore load failure
    }
  }
  
  /// Get responsive subtitle font size based on layout
  double _getResponsiveSubtitleFontSize() {
    return ResponsiveLayout.getSubtitleFontSize(context, _subtitleFontSize);
  }
  
  /// Pick and save a custom font file for subtitle rendering
  /// 
  /// Uses platform-specific file access:
  /// - Android: Storage Access Framework (SAF) for secure font file selection
  /// - Desktop: Traditional file picker with direct file system access
  /// 
  /// Supported font formats: TTF, OTF
  /// The selected font is copied to the app's documents directory and loaded
  /// for use in subtitle rendering across the application.
  Future<void> _pickAndSaveFont(BuildContext context) async {
    // Capture parent context and messenger before awaiting to avoid using deactivated contexts
    final BuildContext parentContext = context;
    
    try {
      PlatformFileInfo? fontFileInfo;
      
      if (Platform.isAndroid) {
        // Use SAF on Android for secure file access
        fontFileInfo = await PlatformFileHandler.readFile(
          mimeTypes: ['font/ttf', 'font/otf', 'application/x-font-ttf', 'application/x-font-opentype', 'application/octet-stream'],
        );
      } else {
        // Use traditional file picker on desktop platforms
        final fontFilePath = await FilePickerSAF.pickFile(
          context: context,
          title: 'Select Font File',
          allowedExtensions: ['.ttf', '.otf'],
        );
        
        if (fontFilePath != null) {
          // Read the file content for desktop platforms
          final sourceFile = File(fontFilePath);
          final content = await sourceFile.readAsBytes();
          
          fontFileInfo = PlatformFileInfo(
            path: fontFilePath,
            content: content,
            isFromSaf: false,
            safUri: null,
          );
        }
      }
      
      if (fontFileInfo == null) return;
  
      // Create fonts directory in app documents
      final appDoc = await getApplicationDocumentsDirectory();
      final fontsDir = Directory('${appDoc.path}${Platform.pathSeparator}fonts');
      if (!await fontsDir.exists()) await fontsDir.create(recursive: true);
      
      // Generate destination file path
      final fileName = fontFileInfo.fileName;
      final dest = File('${fontsDir.path}${Platform.pathSeparator}$fileName');
  
      // If a previous custom font exists, delete it to replace with new one
      try {
        final prevPath = await PreferencesModel.getSubtitleFontPath();
        if (prevPath != null && prevPath.isNotEmpty) {
          final prevFile = File(prevPath);
          if (await prevFile.exists()) {
            await prevFile.delete();
          }
        }
      } catch (e) {
        // ignore deletion errors
      }
  
      // Write font data to destination using bytes from PlatformFileInfo
      await dest.writeAsBytes(fontFileInfo.content);
  
      // Load the font from the saved file
      await _loadFontFromFile(dest);
      
      if (mounted) {
        _setVideoState(() {});
        _fullscreenOverlay?.markNeedsBuild();
      }
      
      // Show success message
      SnackbarHelper.showSuccess(parentContext, 'Font loaded successfully');
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(parentContext, 'Failed to load font: $e');
      }
    }
  }
}
