import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/motion.dart';
import 'icon_mapper.dart';

class GoalIconOption {
  const GoalIconOption(this.api, this.label);
  final String api;
  final String label;
}

/// The icons a savings goal can have, in picker order (names the API
/// stores; see [iconFromApi]).
const goalIcons = [
  GoalIconOption('laptop_mac', 'Laptop'),
  GoalIconOption('phone_iphone', 'Celular'),
  GoalIconOption('headphones', 'Audífonos'),
  GoalIconOption('photo_camera', 'Cámara'),
  GoalIconOption('sports_esports', 'Consola'),
  GoalIconOption('watch', 'Reloj'),
  GoalIconOption('tv', 'Televisor'),
  GoalIconOption('flight', 'Viaje'),
  GoalIconOption('beach_access', 'Playa'),
  GoalIconOption('luggage', 'Maleta'),
  GoalIconOption('directions_car', 'Carro'),
  GoalIconOption('two_wheeler', 'Moto'),
  GoalIconOption('pedal_bike', 'Bicicleta'),
  GoalIconOption('home', 'Casa'),
  GoalIconOption('chair', 'Muebles'),
  GoalIconOption('school', 'Graduación'),
  GoalIconOption('menu_book', 'Libros'),
  GoalIconOption('celebration', 'Fiesta'),
  GoalIconOption('diamond', 'Anillo'),
  GoalIconOption('child_friendly', 'Bebé'),
  GoalIconOption('pets', 'Mascota'),
  GoalIconOption('fitness_center', 'Gimnasio'),
  GoalIconOption('piano', 'Instrumento'),
  GoalIconOption('health_and_safety', 'Emergencias'),
  GoalIconOption('card_giftcard', 'Regalo'),
  GoalIconOption('storefront', 'Negocio'),
  GoalIconOption('volunteer_activism', 'Ayudar'),
  GoalIconOption('auto_awesome', 'Otro sueño'),
];

/// A grid of icon tiles; the selected one fills black with a lime icon
/// (lime with a dark icon in dark mode), like the dock's "+".
class GoalIconPicker extends StatefulWidget {
  const GoalIconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  State<GoalIconPicker> createState() => _GoalIconPickerState();
}

class _GoalIconPickerState extends State<GoalIconPicker> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = Motion.of(context, Motion.fast);
    final visible = _expanded ? [...goalIcons] : goalIcons.take(6).toList();
    if (!visible.any((option) => option.api == widget.selected)) {
      final selected = goalIcons.where(
        (option) => option.api == widget.selected,
      );
      if (selected.isNotEmpty) {
        visible.removeLast();
        visible.add(selected.first);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in visible)
              Builder(
                builder: (context) {
                  final isSelected = option.api == widget.selected;
                  final background = !isSelected
                      ? scheme.surfaceContainerHighest
                      : dark
                      ? palette.accent
                      : palette.pill;
                  final foreground = !isSelected
                      ? scheme.onSurface
                      : dark
                      ? palette.onAccent
                      : palette.accent;
                  return Tooltip(
                    message: option.label,
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: option.label,
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: AppTheme.continuous(15),
                        onTap: () {
                          if (isSelected) return;
                          HapticFeedback.selectionClick();
                          widget.onChanged(option.api);
                        },
                        child: AnimatedScale(
                          scale: isSelected ? 1.06 : 1,
                          duration: duration,
                          curve: Motion.spring,
                          child: AnimatedContainer(
                            duration: duration,
                            curve: Motion.standard,
                            width: 76,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                            decoration: ShapeDecoration(
                              color: background,
                              shape: AppTheme.continuous(15),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  iconFromApi(option.api),
                                  size: 22,
                                  color: foreground,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Ver menos iconos' : 'Ver todos los iconos'),
        ),
      ],
    );
  }
}
