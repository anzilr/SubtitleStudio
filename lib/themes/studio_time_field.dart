import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'studio_design_tokens.dart';

/// Reusable editable time control. It intentionally accepts the existing
/// controller/callbacks so mode changes do not reset time, selection or undo.
class StudioTimeField extends StatelessWidget {
  const StudioTimeField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.onEditingComplete,
    this.inputFormatters = const [],
    this.hasError = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;
  final List<TextInputFormatter> inputFormatters;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioDesignTokens.of(context);
    final theme = Theme.of(context);
    final border = hasError ? tokens.dangerText : tokens.fieldBorder;
    final focused = hasError ? tokens.dangerText : tokens.focusBorder;

    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: inputFormatters,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: hasError ? tokens.dangerText : tokens.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:mm:ss,SSS',
        filled: true,
        fillColor: tokens.fieldSurface,
        labelStyle: TextStyle(color: tokens.mutedText),
        hintStyle: TextStyle(color: tokens.mutedText),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: focused, width: 2),
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: tokens.dangerText),
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: tokens.dangerText, width: 2),
          borderRadius: BorderRadius.circular(StudioRadius.input),
        ),
      ),
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      textInputAction: TextInputAction.next,
      enableIMEPersonalizedLearning: false,
      enableInteractiveSelection: true,
      showCursor: true,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
    );
  }
}
