import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'studio_skin.dart';
import 'theme_controller.dart';

class ThemeSwitcherButton extends ConsumerStatefulWidget {
  const ThemeSwitcherButton({super.key});

  @override
  ConsumerState<ThemeSwitcherButton> createState() => ThemeSwitcherButtonState();
}

class ThemeSwitcherButtonState extends ConsumerState<ThemeSwitcherButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _rotationAnimation =
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(begin: 1, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _sparkleAnimation =
        Tween<double>(begin: 1, end: 1.2).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  IconData _getIconForTheme(StudioAppearance mode) => switch (mode) {
        StudioAppearance.light => Icons.wb_sunny_outlined,
        StudioAppearance.dark => Icons.nights_stay_outlined,
        StudioAppearance.classic => Icons.auto_awesome,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _switchTheme() async {
    final current = ref.read(themeControllerProvider).appearance;
    final next = switch (current) {
      StudioAppearance.light => StudioAppearance.dark,
      StudioAppearance.dark => StudioAppearance.classic,
      StudioAppearance.classic => StudioAppearance.light,
    };

    try {
      await ref.read(themeControllerProvider.notifier).setAppearance(next);
      if (mounted) _controller.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save the appearance mode.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final currentIcon = _getIconForTheme(themeState.appearance);

    return IconButton(
      tooltip: 'Theme: ${themeState.appearance.label}. Tap to switch mode',
      onPressed: themeState.isLoaded ? _switchTheme : null,
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Choose animation based on the current icon
          if (currentIcon == Icons.wb_sunny_outlined) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.1415926535,
              child: Icon(currentIcon),
            );
          } else if (currentIcon == Icons.nights_stay_outlined) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(currentIcon),
            );
          } else {
            return Transform.scale(
              scale: _sparkleAnimation.value,
              child: Icon(currentIcon),
            );
          }
        },
      ),
    );
  }
}
