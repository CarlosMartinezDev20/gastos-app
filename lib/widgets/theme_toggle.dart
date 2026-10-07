import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../providers/theme_provider.dart';
import 'theme_crossfade.dart';

/// Minimal light/dark button for headers: the sun turns into the moon.
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(isDarkModeProvider);
    return DayNightButton(
      value: dark,
      onChanged: (value) {
        HapticFeedback.selectionClick();
        ThemeCrossfade.run(
          context,
          () => ref.read(themeControllerProvider.notifier).setDarkMode(value),
        );
      },
    );
  }
}

/// The stateless button behind [ThemeToggle]; [value] true means dark.
class DayNightButton extends StatelessWidget {
  const DayNightButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = Motion.of(context, Motion.medium);
    return IconButton(
      tooltip: value ? 'Usar tema claro' : 'Usar tema oscuro',
      onPressed: () => onChanged(!value),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: palette.card,
        side: BorderSide(color: palette.hairline),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      icon: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.spring,
        switchOutCurve: Motion.exit,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: -.25, end: 0.0).animate(animation),
          child: ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
        ),
        child: Icon(
          value ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
          key: ValueKey(value),
          size: 20,
        ),
      ),
    );
  }
}
