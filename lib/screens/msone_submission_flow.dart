import 'package:flutter/material.dart';
import 'package:subtitle_studio/screens/msone_submission_screen.dart';
import 'package:subtitle_studio/screens/msone_input_diagnostics.dart';

/// The choice sheet and submission page are *two different routes*. Await the
/// bottom sheet's selection result before pushing the submission route from the
/// caller's still-mounted context. Using the just-popped sheet BuildContext
/// could pick up an unmounted Navigator or race two route transitions.
Future<void> showMsoneSubmissionFlow({
  required BuildContext context,
  required int subtitleCollectionId,
  /// Called after the submission route has left the navigator, before
  /// accepting editor input again. Owned by the caller, not the form.
  VoidCallback? onReturnToEditor,
  @visibleForTesting
  Widget Function(BuildContext, String)? destinationBuilder,
}) async {
  ModalRoute<dynamic>? choiceRoute;
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
    ),
    builder: (sheetContext) {
      choiceRoute ??= ModalRoute.of(sheetContext);
      return Padding(
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
    );
    },
  );

  // Future from showModalBottomSheet resolves at pop request, not after its
  // barrier exits the root Overlay. Never push the next route before the
  // previous barrier is completely removed.
  if (choiceRoute != null) {
    await choiceRoute!.completed;
    debugPrint('MSone flow: choice sheet modal barrier removed');
  }

  // When Android Back dismisses only the sheet, do not push any route.
  if (!context.mounted || selected == null) {
    debugPrint('MSone flow: sheet dismissed; editor mounted=${context.mounted}');
    return;
  }
  debugPrint('MSone flow: opening submission type=$selected');
  final navigator = Navigator.of(context);
  final submissionRoute = MsoneDiagnosticPageRoute<void>(
    debugBarrierName: 'MSone submission',
    builder: (routeContext) => destinationBuilder?.call(
          routeContext,
          selected,
        ) ??
        MsoneSubmissionScreen(
          submissionType: selected,
          subtitleCollectionId: subtitleCollectionId,
        ),
  );
  await navigator.push<void>(submissionRoute);
  // Back can complete Navigator.push before the route is fully disposed and
  // its outgoing overlay/transition has been removed. Wait for that boundary.
  await submissionRoute.completed;
  debugPrint('MSone flow: submission route overlay removed');

  // Flutter's ModalRoute content is IgnorePointer while the Navigator
  // considers a system back gesture in progress. On some Android predictive
  // Back paths the page can dispose before the framework balances that gesture.
  // Recover ONLY after the outgoing page is fully disposed and the resumed
  // Editor's route has completed its own transition.
  final resumedRoute = context.mounted ? ModalRoute.of(context) : null;
  final gestureAtReturn = navigator.userGestureInProgress;
  final resumedRouteSettled = context.mounted &&
      (resumedRoute?.isCurrent ?? false) &&
      (resumedRoute?.animation?.isCompleted ?? false);
  debugPrint('MSone flow: navigator gesture at return=$gestureAtReturn '
      'routeSettled=$resumedRouteSettled');
  if (gestureAtReturn && resumedRouteSettled) {
    navigator.didStopUserGesture();
    debugPrint('MSone flow: recovered completed Android Back gesture; '
        'remaining=${navigator.userGestureInProgress}');
  }
  // A Flutter hot restart never unwinds a Navigator route, so these
  // diagnostics distinguish successful Back navigation from isolate restart.
  debugPrint('MSone flow: returned to editor; mounted=${context.mounted}');
  if (context.mounted) {
    MsoneInputDiagnostics.watchAfterReturn();
    onReturnToEditor?.call();
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
