import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/screen_edit.dart' as legacy;

/// Compatibility wrapper for [legacy.EditScreen].
///
/// This host scopes the Editor's Riverpod providers for one editing session.
class EditScreenHost extends StatefulWidget {
  final int subtitleCollectionId;
  final int? lastEditedIndex;
  final int sessionId;

  @visibleForTesting
  final EditController Function()? controllerFactory;

  const EditScreenHost({
    super.key,
    required this.subtitleCollectionId,
    this.lastEditedIndex,
    required this.sessionId,
    this.controllerFactory,
  });

  @override
  State<EditScreenHost> createState() => _EditScreenHostState();
}

class _EditScreenHostState extends State<EditScreenHost> {
  // Riverpod 3 updates scope overrides when ProviderScope is rebuilt.
  // A theme change may rebuild the Navigator's route builder: recreating
  // overrideWithValue(EditConfiguration(...)) would dispose the editor
  // controller and cause another "Loading..." gate.
  late var _stableOverrides = [
    editConfigurationProvider.overrideWithValue(
      EditConfiguration(
        subtitleCollectionId: widget.subtitleCollectionId,
        sessionId: widget.sessionId,
      ),
    ),
    if (widget.controllerFactory != null)
      editControllerProvider.overrideWith(widget.controllerFactory!),
  ];

  @override
  void initState() {
    super.initState();
    _resetOverrides();
  }

  void _resetOverrides() {
    _stableOverrides = [
      editConfigurationProvider.overrideWithValue(
        EditConfiguration(
          subtitleCollectionId: widget.subtitleCollectionId,
          sessionId: widget.sessionId,
        ),
      ),
      if (widget.controllerFactory != null)
        editControllerProvider.overrideWith(widget.controllerFactory!),
    ];
  }

  @override
  void didUpdateWidget(covariant EditScreenHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitleCollectionId != widget.subtitleCollectionId ||
        oldWidget.sessionId != widget.sessionId ||
        oldWidget.controllerFactory != widget.controllerFactory) {
      _resetOverrides();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey('editor-scope-${widget.sessionId}-${widget.subtitleCollectionId}'),
      overrides: _stableOverrides,
      child: _EditRiverpodHost(
        subtitleCollectionId: widget.subtitleCollectionId,
        lastEditedIndex: widget.lastEditedIndex,
        sessionId: widget.sessionId,
      ),
    );
  }
}

class _EditRiverpodHost extends ConsumerStatefulWidget {
  final int subtitleCollectionId;
  final int? lastEditedIndex;
  final int sessionId;

  const _EditRiverpodHost({
    required this.subtitleCollectionId,
    required this.lastEditedIndex,
    required this.sessionId,
  });

  @override
  ConsumerState<_EditRiverpodHost> createState() => _EditRiverpodHostState();
}

class _EditRiverpodHostState extends ConsumerState<_EditRiverpodHost> {
  bool _initializationStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initializationStarted) return;
    _initializationStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(editControllerProvider.notifier)
          .initialize(lastEditedIndex: widget.lastEditedIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editControllerProvider);

    ref.listen<EditState>(editControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null && message != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(editControllerProvider.notifier).clearError();
      }
    });

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return legacy.EditScreen(
      subtitleCollectionId: widget.subtitleCollectionId,
      lastEditedIndex: widget.lastEditedIndex,
      sessionId: widget.sessionId,
    );
  }
}
