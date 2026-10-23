import 'package:flutter/material.dart';

/// Search button shared by both dictionaries. The foreground always uses
/// onPrimary, including white-primary Carbon Zero Dark/Classic mode.
class DictionarySearchAction extends StatelessWidget {
  const DictionarySearchAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.search),
      label: const Text('Search',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}
