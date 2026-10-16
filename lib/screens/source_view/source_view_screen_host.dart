import 'dart:async';
import 'package:flutter/material.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/source_view/source_view_controller.dart';
import 'package:subtitle_studio/screens/source_view/source_view_state.dart';
import 'package:subtitle_studio/screens/edit/widgets/source_view_pane.dart';
import 'package:subtitle_studio/utils/snackbar_helper.dart';

/// Riverpod-enabled compatibility wrapper for SourceViewScreen
/// 
/// This widget provides the Riverpod architecture for the source view screen,
/// managing state through SourceViewController and handling side effects
/// like error messages and save notifications.
/// 
/// Features:
/// - Automatic state management with Riverpod pattern
/// - Error handling with user-friendly messages
/// - Save operation feedback
/// - Performance optimizations with proper widget rebuilding
class SourceViewScreenHost extends StatefulWidget {
  /// Path to the SRT file to be displayed and edited.
  final String filePath;
  final String? displayName;
  final String? safUri;
  final String? fileContent;

  @visibleForTesting
  final SourceViewController Function()? controllerFactory;

  const SourceViewScreenHost({
    super.key,
    required this.filePath,
    this.displayName,
    this.safUri,
    this.fileContent,
    this.controllerFactory,
  });

  @override
  State<SourceViewScreenHost> createState() => _SourceViewScreenHostState();
}

class _SourceViewScreenHostState extends State<SourceViewScreenHost> {
  // Riverpod 3 can update scope overrides when an inherited Theme rebuilds.
  // Do not replace the route-owned config while it is editing unsaved SRT.
  late var _stableOverrides = [
    sourceViewConfigProvider.overrideWithValue(
      SourceViewConfig(
        filePath: widget.filePath,
        displayName: widget.displayName,
        safUri: widget.safUri,
        fileContent: widget.fileContent,
      ),
    ),
    if (widget.controllerFactory != null)
      sourceViewControllerProvider.overrideWith(widget.controllerFactory!),
  ];

  @override
  void initState() {
    super.initState();
    _resetOverrides();
  }

  void _resetOverrides() {
    _stableOverrides = [
      sourceViewConfigProvider.overrideWithValue(
        SourceViewConfig(
          filePath: widget.filePath,
          displayName: widget.displayName,
          safUri: widget.safUri,
          fileContent: widget.fileContent,
        ),
      ),
      if (widget.controllerFactory != null)
        sourceViewControllerProvider.overrideWith(widget.controllerFactory!),
    ];
  }

  @override
  void didUpdateWidget(covariant SourceViewScreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.displayName != widget.displayName ||
        oldWidget.safUri != widget.safUri ||
        oldWidget.fileContent != widget.fileContent ||
        oldWidget.controllerFactory != widget.controllerFactory) {
      _resetOverrides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('source-view-scope-${widget.filePath}-${widget.safUri ?? ''}'),
      overrides: _stableOverrides,
      child: const _SourceViewRiverpodHost(),
    );
  }
}

class _SourceViewRiverpodHost extends ConsumerWidget {
  const _SourceViewRiverpodHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sourceViewControllerProvider);
    final tokens = StudioDesignTokens.of(context);
    final controller = ref.read(sourceViewControllerProvider.notifier);

    ref.listen<SourceViewState>(sourceViewControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        SnackbarHelper.showError(context, next.errorMessage!);
        controller.clearMessages();
      }

      if (next.saveMessage != null &&
          next.saveMessage != previous?.saveMessage) {
        if (next.saveSuccessful) {
          if (next.saveMessage!.contains('cache')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.saveMessage!,
                        style: TextStyle(color: tokens.onCaution)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        controller.saveAsFile();
                      },
                      child: Text(
                        'Tap here to save to a new location ➤',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: tokens.onCaution,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: tokens.caution,
                duration: const Duration(seconds: 8),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            SnackbarHelper.showSuccess(context, next.saveMessage!);
          }
        } else {
          SnackbarHelper.showError(context, next.saveMessage!);
        }
        controller.clearMessages();
      }
    });

    return _SourceViewWidget(
      state: state,
      controller: controller,
    );
  }
}

/// The actual source view widget implementation
/// 
/// This widget is separated from the Riverpod wrapper to optimize rebuilds
/// and provide better performance. It uses const constructors where possible
/// and implements efficient ListView building.
class _SourceViewWidget extends StatelessWidget {
  final SourceViewState state;
  final SourceViewController controller;
  
  const _SourceViewWidget({
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onWillPop(context);
        if (shouldPop && context.mounted) {
          navigator.pop();
        }
      },
      child: _SourceViewShortcuts(
        controller: controller,
        child: Scaffold(
          backgroundColor: tokens.surface,
          resizeToAvoidBottomInset: true,
          appBar: _buildAppBar(context),
          body: _buildBody(context),
        ),
      ),
    );
  }

  /// Build the app bar with save functionality
  AppBar _buildAppBar(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    return AppBar(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.onSurface,
      iconTheme: IconThemeData(
        color: tokens.onSurface,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source View',
            style: TextStyle(fontSize: 16),
          ),
          Text(
            state.displayFileName,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.normal,
              color: tokens.mutedText,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.save,
            color: state.hasUnsavedChanges 
                ? tokens.primaryAction
                : tokens.onSurface,
          ),
          tooltip: 'Save Options',
          enabled: !state.isSaving,
          onSelected: (String value) {
            final cubit = controller;
            switch (value) {
              case 'save':
                cubit.saveFile();
                break;
              case 'saveAs':
                cubit.saveAsFile();
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'save',
              child: Row(
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Save (Ctrl+S)'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'saveAs',
              child: Row(
                children: [
                  Icon(Icons.save_as),
                  SizedBox(width: 8),
                  Text('Save As...'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build the main body content based on current state
  Widget _buildBody(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading file...'),
          ],
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: tokens.dangerText,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.dangerText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.reloadFile(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Main content with optimized ListView
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: RawSrtEditor(
        initialText: controller.rawSourceText ?? state.toSrtContent(),
        onChanged: controller.updateRawSourceText,
      ),
    );
  }

  /// Handle back navigation with unsaved changes check
  Future<bool> _onWillPop(BuildContext context) async {
    final tokens = StudioDesignTokens.of(context);
    if (!state.hasUnsavedChanges) {
      return true;
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Do you want to save before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: tokens.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Discard',
              style: TextStyle(
                color: tokens.dangerText,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              controller.saveFile();
              if (context.mounted) {
                navigator.pop(true);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: tokens.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }
}

/// Keyboard shortcuts widget for save functionality
class _SourceViewShortcuts extends StatelessWidget {
  final Widget child;
  final SourceViewController controller;
  
  const _SourceViewShortcuts({
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const _SaveIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_SaveIntent intent) {
              controller.saveFile();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: false,
          child: child,
        ),
      ),
    );
  }
}

/// Intent class for save keyboard shortcut
class _SaveIntent extends Intent {
  const _SaveIntent();
}

