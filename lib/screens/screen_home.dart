// Subtitle Studio v3 - Home Screen
//
// This is the main landing screen of the application that serves as the central hub
// for all subtitle editing workflows. It provides access to recent projects,
// creation of new subtitle files, importing existing files, and extracting
// subtitles from video files.
//
// Key Features:
// - Recent sessions display with search functionality
// - Multiple creation workflows (new, import, extract)
// - File association handling (opening .srt files from external apps)
// - First-time user tutorial system
// - Settings and help access
// - Theme switching capabilities
//
// Architecture:
// - Uses StatefulWidget with TickerProviderStateMixin for animations
// - Riverpod for application state and Provider for legacy theme wiring
// - Database integration for session management
// - Custom floating action buttons for primary actions
// - Material Design with custom animations
//
// iOS Port Considerations:
// - Replace Material Design with iOS native components
// - Convert FloatingActionButton to iOS action sheets or toolbars
// - Use iOS navigation patterns (tab bar, navigation controller)
// - Map Riverpod state to platform-appropriate observable state if ported natively
// - Implement iOS-specific file handling and document picker
// - Adapt animations to iOS conventions (UIView animations)

import 'package:flutter/foundation.dart';     // Flutter debugging and platform detection
import 'package:flutter/material.dart';      // Material Design components
import 'package:flutter/services.dart';      // Hardware services and keyboard support
import 'dart:convert';                        // For encoding/decoding file content
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod state management
import 'package:subtitle_studio/screens/edit_line/edit_line_host.dart'; // EditSubtitleScreenHost wrapper
import 'package:subtitle_studio/screens/screen_help.dart';      // Help documentation
import 'package:subtitle_studio/screens/screen_source_view.dart'; // Source view screen
import 'package:subtitle_studio/screens/home/home_controller.dart'; // Home Riverpod controller
import 'package:subtitle_studio/screens/home/home_state.dart';  // Home screen State
import 'package:subtitle_studio/screens/home/models/session_summary.dart';
import 'package:subtitle_studio/screens/home/widgets/session_card.dart';
// Removed startup_permission_manager - not needed with pure SAF implementation
import 'package:subtitle_studio/utils/file_picker_utils_saf.dart'; // File picker utilities
import 'package:subtitle_studio/utils/saf_file_handler.dart';    // SAF file operations
import 'package:subtitle_studio/utils/saf_path_converter.dart';  // SAF path conversion
import '../utils/responsive_layout.dart';     // Responsive layout utilities
import '../database/models/models.dart';     // Data models
import '../themes/theme_switcher_button.dart'; // Theme toggle component
import 'package:subtitle_studio/widgets/settings_sheet.dart';   // Settings modal
import 'package:subtitle_studio/widgets/create_subtitle_sheet.dart'; // New project creation
import 'package:subtitle_studio/widgets/import_project_sheet.dart'; // Project import
import 'package:subtitle_studio/widgets/subtitle_import_options_sheet.dart'; // Import workflow
import 'package:subtitle_studio/widgets/subtitle_extract_options_sheet.dart'; // Video extraction
import 'package:subtitle_studio/utils/logging_helpers.dart';    // Logging utilities
import 'package:subtitle_studio/utils/snackbar_helper.dart';    // User notifications
import 'package:subtitle_studio/utils/update_manager.dart';     // In-app update functionality
import 'package:subtitle_studio/widgets/first_time_instructions.dart'; // Tutorial system
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart' as hotkey; // Keyboard shortcuts
import 'edit/edit_screen_host.dart';          // Main editing interface with Riverpod host

part 'home/parts/home_session_widgets.dart';
part 'home/parts/home_fab_widgets.dart';
part 'home/parts/home_navigation_actions.dart';
part 'home/parts/home_confirmation_dialogs.dart';

/// Main home screen widget serving as the application's primary interface
/// 
/// This screen provides the central hub for all subtitle editing workflows:
/// 
/// **Primary Functions:**
/// - Display recent editing sessions with search capabilities
/// - Provide quick access to create new subtitle projects
/// - Handle file imports from various sources
/// - Extract subtitles from video files using FFmpeg
/// - Manage user settings and preferences
/// - Provide help and documentation access
/// 
/// **User Experience Features:**
/// - Animated floating action buttons for primary actions
/// - Search functionality for finding specific sessions
/// - Visual feedback for loading states
/// - Smooth transitions between screens
/// - First-time user guidance system
/// 
/// **Technical Implementation:**
/// - State management using Riverpod
/// - Clean architecture with repository pattern
/// - Comprehensive logging throughout
/// - File association handling for external app integration
/// - Custom FAB implementation for enhanced UX
/// 
/// **iOS Port Implementation Notes:**
/// - Replace FloatingActionButton with iOS action sheets or bottom toolbar
/// - Use UITableView or UICollectionView for recent sessions list
/// - Implement iOS document picker for file import workflows
/// - Replace Material search with iOS UISearchController
/// - Use iOS navigation patterns (UINavigationController, UITabBarController)
/// - Convert animations to UIView animation blocks or Core Animation
class HomeScreen extends StatelessWidget {
  /// Optional file path from intent/file association
  /// When app is opened with a .srt file, this contains the file path
  final String? initialFilePath;
  
  /// Optional file name extracted from intent
  /// Used for display purposes when file association opens the app
  final String? initialFileName;
  
  /// Whether the initial file is a .msone project file
  /// Used to determine if import project sheet should be shown
  final bool isProjectFile;
  
  /// Original SAF URI for files opened via intent
  /// Used to preserve the content URI for database storage
  final String? originalSafUri;

  const HomeScreen({
    super.key,
    this.initialFilePath,    // File path from external app intent
    this.initialFileName,    // Display name from external app intent
    this.isProjectFile = false, // Whether file is .msone project
    this.originalSafUri,     // Original SAF URI for database storage
  });

  @override
  Widget build(BuildContext context) {
    return _HomeScreenContent(
      initialFilePath: initialFilePath,
      initialFileName: initialFileName,
      isProjectFile: isProjectFile,
      originalSafUri: originalSafUri,
    );
  }
}

/// Internal content widget for the home screen
/// 
/// This widget handles the actual UI rendering and user interactions,
/// while HomeScreen above keeps route/input concerns separate.
class _HomeScreenContent extends ConsumerStatefulWidget {
  final String? initialFilePath;
  final String? initialFileName;
  final bool isProjectFile;
  final String? originalSafUri;

  const _HomeScreenContent({
    this.initialFilePath,
    this.initialFileName,
    this.isProjectFile = false,
    this.originalSafUri,
  });

  @override
  ConsumerState<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<_HomeScreenContent> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _fadeController;
  late AnimationController _customFabController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _customFabAnimation;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  // GlobalKeys for tutorials
  final GlobalKey _themeSwitcherKey = GlobalKey();
  final GlobalKey _settingsButtonKey = GlobalKey();
  final GlobalKey _createButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    logInfo('HomeScreen initialized');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(homeControllerProvider.notifier).loadSessions();
      }
    });

    // Add app lifecycle observer for update checks
    WidgetsBinding.instance.addObserver(this);

    // Initialize fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize custom FAB animation
    _customFabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _customFabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _customFabController, curve: Curves.easeInOut),
    );

    // Handle initial file path from intent
    _handleInitialFilePath();
    
    // SAF implementation does not require startup permissions
    // Permission dialogs removed for pure SAF implementation
    
    // Check for flexible update completion
    _checkFlexibleUpdateCompletion();
    
    // Check for updates automatically after a delay
    _checkForUpdatesAutomatically();
    
    // Register hotkey shortcuts
    _registerHotkeyShortcuts();
  }

  /// Check for updates automatically after the home screen loads
  Future<void> _checkForUpdatesAutomatically() async {
    try {
      // Wait for the home screen to fully load and animations to complete
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        final updateInfo = await UpdateManager.instance.checkForUpdate();
        if (updateInfo != null && mounted) {
          UpdateManager.instance.showUpdateDialog(context, updateInfo);
        }
      }
    } catch (e) {
      logError('Error checking for updates automatically: $e');
    }
  }

  Future<void> _handleInitialFilePath() async {
    if (widget.initialFilePath == null) return;

    // Navigation/dialog work launched from initState should wait until the
    // first frame has attached this route. A fixed delay is device-speed
    // dependent and can either be unnecessarily slow or still too early.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (widget.isProjectFile) {
      _handleImportProject(
        preselectedFilePath: widget.initialFilePath!,
        originalSafUri: widget.originalSafUri,
      );
    } else {
      _showImportWithFilePath(
        widget.initialFilePath!,
        widget.initialFileName,
        originalSafUri: widget.originalSafUri,
      );
    }
  }

  /// Register hotkey shortcuts using MSoneHotkeyManager
  Future<void> _registerHotkeyShortcuts() async {
    await hotkey.MSoneHotkeyManager.instance.registerHomeScreenShortcuts(
      onOpenSrtFile: _handleOpenSrtFileShortcut,
      onImportMsoneFile: _handleImportMsoneFileShortcut,
      onExtractSubtitleFromVideo: _handleExtractSubtitleFromVideoShortcut,
      onCreateNew: _handleCreateNewShortcut,
      onHelp: _handleHelpShortcut,
      onSettings: _handleSettingsShortcut,
    );
  }

  /// Re-register HomeScreen shortcuts after returning from other screens
  /// This ensures that shared shortcuts (help, settings) work correctly in HomeScreen
  Future<void> _reRegisterHomeScreenShortcuts() async {
    // First unregister any remaining shared shortcuts that might still point to disposed widgets
    await hotkey.MSoneHotkeyManager.instance.unregisterCallback(hotkey.HotkeyAction.help);
    await hotkey.MSoneHotkeyManager.instance.unregisterCallback(hotkey.HotkeyAction.settings);
    
    // Then re-register them with HomeScreen's handlers
    await hotkey.MSoneHotkeyManager.instance.registerCallback(hotkey.HotkeyAction.help, _handleHelpShortcut);
    await hotkey.MSoneHotkeyManager.instance.registerCallback(hotkey.HotkeyAction.settings, _handleSettingsShortcut);
  }

  // Hotkey shortcut handlers
  void _handleOpenSrtFileShortcut() {
    _handleImport();
  }

  void _handleImportMsoneFileShortcut() {
    _handleImportProject();
  }

  void _handleExtractSubtitleFromVideoShortcut() {
    _handleExtract(); // This opens the extract options directly
  }

  void _handleCreateNewShortcut() {
    _handleCreate();
  }

  void _handleHelpShortcut() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpScreen()),
    );
  }

  void _handleSettingsShortcut() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SettingsSheet(
        onSettingsChanged: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Unregister hotkey shortcuts
    hotkey.MSoneHotkeyManager.instance.unregisterAll();
    
    _fadeController.dispose();
    _customFabController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for flexible update completion when app resumes
    if (state == AppLifecycleState.resumed) {
      _checkFlexibleUpdateCompletion();
      // Also refresh sessions in case they were updated while app was paused
      ref.read(homeControllerProvider.notifier).loadSessions();
    }
  }

  /// Check if a flexible update has completed downloading and is ready to install
  Future<void> _checkFlexibleUpdateCompletion() async {
    try {
      await UpdateManager.instance.checkFlexibleUpdateCompletion(context);
    } catch (e) {
      logError('Error checking flexible update completion: $e');
    }
  }

  Future<void> _deleteSession(Session session) async {
    try {
      await ref.read(homeControllerProvider.notifier).deleteSession(session);
      
      // Unfocus search field to prevent keyboard from showing
      _searchFocusNode.unfocus();
      
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Deleted "${session.fileName}"', duration: const Duration(seconds: 2));
      }
    } catch (e) {
      // Error is surfaced by the Riverpod state listener
    }
  }

  List<String> _getHomeInstructions() {
    return [
      'Use the help button (❔) to access comprehensive documentation and guides.',
      'Use the theme switcher button (✨/🌙/☀️) in the top-right to switch between dark, light, and classic themes.',
      'Tap the settings button (⚙️) to access app preferences and configure MSone features.',
      'Use the sort button to organize sessions by last opened, last created, or name.',
      'Use the floating action buttons to create new subtitles, import files, extract from video, or continue editing.',
      'Each session card shows editing progress, languages detected, and file information.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);

    ref.listen<HomeState>(homeControllerProvider, (previous, next) {
      // Handle newly reported errors once, then clear them from state.
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        SnackbarHelper.showError(context, next.errorMessage!);
        ref.read(homeControllerProvider.notifier).clearError();
      }

      // Start fade animation when the initial session load completes.
      if (!next.isLoading &&
          previous?.isLoading != false &&
          _fadeController.status == AnimationStatus.dismissed) {
        _fadeController.forward();
      }
    });

    return FirstTimeInstructions(
      screenName: 'home',
      instructions: _getHomeInstructions(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Subtitle Studio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            ),
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            // Sort button - only show if there are sessions
            if (state.hasSessions)
              PopupMenuButton<SessionSortOption>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort Sessions',
                onSelected: (SessionSortOption option) {
                  ref.read(homeControllerProvider.notifier).changeSortOption(option);
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<SessionSortOption>>[
                  PopupMenuItem<SessionSortOption>(
                    value: SessionSortOption.lastOpened,
                    child: Row(
                      children: [
                        Icon(
                          state.sortOption == SessionSortOption.lastOpened
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: state.sortOption == SessionSortOption.lastOpened
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Text('Last Opened'),
                      ],
                    ),
                  ),
                  PopupMenuItem<SessionSortOption>(
                    value: SessionSortOption.lastCreated,
                    child: Row(
                      children: [
                        Icon(
                          state.sortOption == SessionSortOption.lastCreated
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: state.sortOption == SessionSortOption.lastCreated
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Text('Last Created'),
                      ],
                    ),
                  ),
                  PopupMenuItem<SessionSortOption>(
                    value: SessionSortOption.name,
                    child: Row(
                      children: [
                        Icon(
                          state.sortOption == SessionSortOption.name
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: state.sortOption == SessionSortOption.name
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Text('Name (A-Z)'),
                      ],
                    ),
                  ),
                  PopupMenuItem<SessionSortOption>(
                    value: SessionSortOption.nameDesc,
                    child: Row(
                      children: [
                        Icon(
                          state.sortOption == SessionSortOption.nameDesc
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                          color: state.sortOption == SessionSortOption.nameDesc
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 12),
                        const Text('Name (Z-A)'),
                      ],
                    ),
                  ),
                ],
              ),
            // Clear All Sessions button - only show if there are sessions
            if (state.hasSessions)
              IconButton(
                onPressed: () => _showClearAllSessionsDialog(),
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All Sessions',
              ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help & Documentation',
            ),
            ThemeSwitcherButton(key: _themeSwitcherKey),
            IconButton(
              key: _settingsButtonKey,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                  ),
                  builder: (context) => SettingsSheet(
                    onSettingsChanged: () {
                      setState(() {});
                    },
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () {
              // Collapse FAB when tapping anywhere on the screen
              if (state.isFabExpanded) {
                _toggleCustomFab();
              }
              // Unfocus search field
              _searchFocusNode.unfocus();
            },
            child: Stack(
              children: [
                state.isLoading
                    ? _buildLoadingState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            _buildWelcomeHeader(state),
                            _buildSearchBar(state),
                            Expanded(child: _buildSessionsList(state)),
                          ],
                        ),
                      ),
                _buildCustomFAB(state),
              ],
            ),
          ),
        ),
        floatingActionButton: null, // Remove default FAB
      ),
    );
  }


}
