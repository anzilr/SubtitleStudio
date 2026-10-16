import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:subtitle_studio/themes/studio_design_tokens.dart';

Future<void> showBatchDeleteConfirmationSheet({
  required BuildContext context,
  required int selectedCount,
  required Future<void> Function() onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BatchDeleteConfirmationSheet(
      selectedCount: selectedCount,
      onConfirm: onConfirm,
    ),
  );
}

class _BatchDeleteConfirmationSheet extends StatefulWidget {
  final int selectedCount;
  final Future<void> Function() onConfirm;

  const _BatchDeleteConfirmationSheet({
    required this.selectedCount,
    required this.onConfirm,
  });

  @override
  State<_BatchDeleteConfirmationSheet> createState() =>
      _BatchDeleteConfirmationSheetState();
}

class _BatchDeleteConfirmationSheetState
    extends State<_BatchDeleteConfirmationSheet> {
  final FocusNode _focusNode = FocusNode();
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    _confirming = true;
    // Match the existing callback contract: dismiss before asynchronous work.
    Navigator.pop(context);
    await widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final text = Theme.of(context).textTheme;
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          unawaited(_confirm());
        }
      },
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(StudioRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.all(StudioSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(StudioSpacing.sm),
                    decoration: BoxDecoration(
                      color: tokens.dangerText.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(StudioRadius.card),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: tokens.dangerText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: StudioSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Selected Subtitles',
                          style: text.titleLarge?.copyWith(
                            color: tokens.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: StudioSpacing.xxs),
                        Text(
                          'This action cannot be undone',
                          style: text.bodyMedium?.copyWith(
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(StudioSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.fieldSurface,
                  borderRadius: BorderRadius.circular(StudioRadius.card),
                  border: Border.all(color: tokens.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: tokens.dangerText,
                      size: StudioSizing.icon,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(
                        'Are you sure you want to delete '
                        '${widget.selectedCount} subtitle lines? '
                        'This action cannot be undone.',
                        style: text.bodyMedium?.copyWith(
                          color: tokens.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StudioSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: StudioSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.dangerText,
                        foregroundColor: tokens.surface,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<int>?> showSelectByIndexSheet({
  required BuildContext context,
  required int totalLines,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
    ),
    builder: (_) => _SelectByIndexSheet(totalLines: totalLines),
  );
}

class _SelectByIndexSheet extends StatefulWidget {
  final int totalLines;

  const _SelectByIndexSheet({required this.totalLines});

  @override
  State<_SelectByIndexSheet> createState() => _SelectByIndexSheetState();
}

class _SelectByIndexSheetState extends State<_SelectByIndexSheet> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _submit() {
    final start = int.tryParse(_startController.text);
    final end = int.tryParse(_endController.text);

    if (start == null || end == null) {
      setState(() => _errorMessage = 'Please enter valid numbers');
      return;
    }
    if (start < 1 || end > widget.totalLines || start > end) {
      setState(
        () => _errorMessage =
            'Invalid range (valid: 1-${widget.totalLines})',
      );
      return;
    }

    Navigator.pop(context, <int>[start - 1, end - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = StudioDesignTokens.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryAction.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.format_list_numbered,
                  color: colors.primaryAction,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Select by Index Range',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Enter the start and end indices (1 to ${widget.totalLines}).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _field(
                  _startController,
                  'Start Index',
                  '1',
                  Icons.play_arrow,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _field(
                  _endController,
                  'End Index',
                  '${widget.totalLines}',
                  Icons.stop,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: colors.dangerText),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Select'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
  ) {
    final tokens = StudioDesignTokens.of(context);
    final radius = BorderRadius.circular(StudioRadius.input);
    return TextField(
      controller: controller,
      style: TextStyle(color: tokens.onSurface),
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        filled: true,
        fillColor: tokens.fieldSurface,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: tokens.primaryAction),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.focusBorder, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.md,
          vertical: StudioSpacing.md,
        ),
      ),
    );
  }
}

Future<void> showShiftSelectedTimesSheet({
  required BuildContext context,
  required String initialStartTime,
  required String initialEndTime,
  required Future<bool> Function(
    String newStartTime,
    String newEndTime,
  ) onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
    ),
    builder: (_) => _ShiftSelectedTimesSheet(
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
      onApply: onApply,
    ),
  );
}

class _ShiftSelectedTimesSheet extends StatefulWidget {
  final String initialStartTime;
  final String initialEndTime;
  final Future<bool> Function(String, String) onApply;

  const _ShiftSelectedTimesSheet({
    required this.initialStartTime,
    required this.initialEndTime,
    required this.onApply,
  });

  @override
  State<_ShiftSelectedTimesSheet> createState() =>
      _ShiftSelectedTimesSheetState();
}

class _ShiftSelectedTimesSheetState
    extends State<_ShiftSelectedTimesSheet> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _startController =
        TextEditingController(text: widget.initialStartTime);
    _endController =
        TextEditingController(text: widget.initialEndTime);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final shouldClose = await widget.onApply(
      _startController.text,
      _endController.text,
    );

    if (!mounted) return;
    if (shouldClose) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StudioDesignTokens.of(context);
    final muted = colors.mutedText;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(StudioRadius.sheet)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryAction.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.timer,
                      color: colors.primaryAction,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Selected Subtitles',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Adjust timing for selected subtitle lines',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Enter new timecodes for the first and last selected subtitles. Only selected lines will be affected.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                ),
              ),
              const SizedBox(height: 24),
              _timeField(
                controller: _startController,
                label: 'First selected subtitle starts at:',
              ),
              const SizedBox(height: 16),
              _timeField(
                controller: _endController,
                label: 'Last selected subtitle ends at:',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _isProcessing ? null : _apply,
                        child: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimaryAction,
                                ),
                              )
                            : const Text('Apply'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeField({
    required TextEditingController controller,
    required String label,
  }) {
    final tokens = StudioDesignTokens.of(context);
    final radius = BorderRadius.circular(StudioRadius.input);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: controller,
          style: TextStyle(color: tokens.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: tokens.fieldSurface,
            hintText: '00:00:00,000',
            prefixIcon: Icon(Icons.access_time, color: tokens.primaryAction),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: tokens.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: tokens.focusBorder, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.md,
              vertical: StudioSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
