import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  IconData _getIconForTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.wb_sunny_outlined;
      case ThemeMode.dark:
        return Icons.nights_stay_outlined;
      case ThemeMode.system:
        return Icons.auto_awesome;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchTheme() {
    final state = ref.read(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    switch (state.themeMode) {
      case ThemeMode.light:
        controller.setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        controller.setTheme(ThemeMode.system);
        break;
      case ThemeMode.system:
        controller.setTheme(ThemeMode.light);
        break;
    }

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final currentIcon = _getIconForTheme(themeState.themeMode);

    return IconButton(
      onPressed: _switchTheme,
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
              child: Icon(
                currentIcon,
                color: Colors.white,
              ),
            );
          }
        },
      ),
    );
  }
}
