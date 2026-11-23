import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_accent.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import 'ios_ui.dart';

/// The accent swatches of Perfil → Apariencia: one circle per [AppAccent],
/// the chosen one ringed. Each takes an equal share of the row, so the five
/// fit from 320 px wide; the names shrink rather than wrap with large text.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppAccent selected;
  final ValueChanged<AppAccent> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final accent in AppAccent.values)
          Expanded(
            child: _Swatch(
              accent: accent,
              selected: accent == selected,
              onTap: () {
                if (accent == selected) return;
                HapticFeedback.selectionClick();
                onChanged(accent);
              },
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final duration = Motion.of(context, Motion.fast);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color ${accent.label}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressScale(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: duration,
                        curve: Motion.standard,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: onSurface, width: 2),
                          ),
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.accent,
                          border: Border.all(
                            color: context.palette.hairline,
                            width: AppPalette.separatorWidth,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    accent.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? onSurface : context.palette.muted,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
