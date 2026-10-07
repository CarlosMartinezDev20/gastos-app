import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
    this.trackColor,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      builder: (context, animated, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor:
              trackColor ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
          color: color ?? context.palette.pill,
        ),
      ),
    );
  }
}
