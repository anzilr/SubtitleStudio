import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtitle_studio/screens/edit/edit_controller.dart';
import 'package:subtitle_studio/screens/edit/edit_state.dart';
import 'package:subtitle_studio/screens/screen_edit.dart' as legacy;

/// Compatibility wrapper for [legacy.EditScreen].
///
/// This host scopes the Editor's Riverpod providers for one editing session.
class EditScreenHost extends StatelessWidget {
  final int subtitleCollectionId;
  final int? lastEditedIndex;
  final int sessionId;

  const EditScreenHost({
    super.key,
    required this.subtitleCollectionId,
    this.lastEditedIndex,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        editConfigurationProvider.overrideWithValue(
          EditConfiguration(
            subtitleCollectionId: subtitleCollectionId,
            sessionId: sessionId,
          ),
        ),
      ],
      child: _EditRiverpodHost(
        subtitleCollectionId: subtitleCollectionId,
        lastEditedIndex: lastEditedIndex,
        sessionId: sessionId,
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
