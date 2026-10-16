import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/msone_submission_screen.dart';

/// The choice sheet and submission page are *two different routes*. Await the
/// bottom sheet's selection result before pushing the submission route from the
/// caller's still-mounted context. Using the just-popped sheet BuildContext
/// could pick up an unmounted Navigator or race two route transitions.
Future<void> showMsoneSubmissionFlow({
  required BuildContext context,
  required int subtitleCollectionId,
  @visibleForTesting
  Widget Function(BuildContext, String)? destinationBuilder,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Submit to Msone',
            style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _SubmissionChoice(
            title: 'Existing Translator',
            subtitle: 'For translators with existing accounts',
            icon: Icons.person,
            onTap: () => Navigator.of(sheetContext).pop('main'),
          ),
          const SizedBox(height: 16),
          _SubmissionChoice(
            title: 'Fresher',
            subtitle: 'For new translators',
            icon: Icons.person_add,
            onTap: () => Navigator.of(sheetContext).pop('fresher'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

  // When Android Back dismisses only the sheet, do not push any route.
  if (!context.mounted || selected == null) {
    debugPrint('MSone flow: sheet dismissed; editor mounted=${context.mounted}');
    return;
  }
  debugPrint('MSone flow: opening submission type=$selected');
  final navigator = Navigator.of(context);
  await navigator.push<void>(MaterialPageRoute<void>(
    builder: (routeContext) => destinationBuilder?.call(
          routeContext,
          selected,
        ) ??
        MsoneSubmissionScreen(
          submissionType: selected,
          subtitleCollectionId: subtitleCollectionId,
        ),
  ));
  // This fires for *normal Android Back*. Hot restart does not unwind a
  // Navigator route, so its absence helps distinguish a native crash.
  debugPrint('MSone flow: returned to editor; mounted=${context.mounted}');
  if (context.mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        debugPrint('MSone flow: editor rendered a frame after Back');
      }
    });
  }
}

class _SubmissionChoice extends StatelessWidget {
  const _SubmissionChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
