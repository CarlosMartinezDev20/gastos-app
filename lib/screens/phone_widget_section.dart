import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/phone_widget.dart';
import '../providers/phone_widget_provider.dart';
import '../widgets/ios_ui.dart';
import '../widgets/phone_widget_preview.dart';

/// Chooses what the phone's home-screen widget shows and its colors, with a
/// live preview. On Android it can also add the widget from here.
class PhoneWidgetSection extends ConsumerWidget {
  const PhoneWidgetSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(phoneWidgetSettingsProvider);
    final controller = ref.read(phoneWidgetSettingsProvider.notifier);
    final payload = ref.watch(phoneWidgetPayloadProvider);
    final service = ref.watch(phoneWidgetServiceProvider);
    final label = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: palette.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Widget del teléfono'),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  // A wallpaper-like backdrop for the preview.
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9FB8FF), Color(0xFFF6B6C8)],
                  ),
                ),
                alignment: Alignment.center,
                child: payload == null
                    ? const SizedBox(
                        height: PhoneWidgetPreview.side,
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    : PhoneWidgetPreview(payload: payload),
              ),
              const SizedBox(height: 18),
              Text('Muestra', style: label),
              const SizedBox(height: 8),
              SegmentedTabs<PhoneWidgetContent>(
                selected: settings.content,
                onChanged: controller.setContent,
                segments: {
                  for (final c in PhoneWidgetContent.values) c: c.label,
                },
              ),
              const SizedBox(height: 18),
              Text('Color', style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final theme in PhoneWidgetTheme.values)
                    _ThemeSwatch(
                      theme: theme,
                      selected: theme == settings.theme,
                      onTap: () => controller.setTheme(theme),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (service.canPin)
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await service.requestPin();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tu teléfono no permite añadirlo desde aquí. '
                            'Mantén presionada la pantalla de inicio y '
                            'busca "appgastos" en Widgets.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('Añadir a la pantalla de inicio'),
                )
              else
                Text(
                  service.supported
                      ? 'Mantén presionada la pantalla de inicio, toca + y '
                            'busca "appgastos" para añadirlo.'
                      : 'Disponible en la app de Android y iPhone: el widget '
                            'usará el contenido y el color que elijas aquí.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final PhoneWidgetTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Widget ${theme.label}',
      child: Tooltip(
        message: theme.label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? ring : context.palette.hairline,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(theme.background),
              ),
              child: selected
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 20,
                      color: Color(theme.foreground),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
