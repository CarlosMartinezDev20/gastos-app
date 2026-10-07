import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/home_layout.dart';
import '../models/dashboard.dart';
import '../providers/finance_providers.dart';
import '../providers/home_layout_provider.dart';
import '../widgets/app_states.dart';
import '../widgets/home_cards.dart';
import '../widgets/ios_ui.dart';
import 'phone_widget_section.dart';
import '../core/theme/motion.dart';

/// Width of a compact widget's preview (about half a phone screen).
const _compactPreviewWidth = 190.0;

IconData homeWidgetIcon(HomeWidgetType type) => switch (type) {
  HomeWidgetType.balance => CupertinoIcons.creditcard,
  HomeWidgetType.income => CupertinoIcons.arrow_down_left,
  HomeWidgetType.spending => CupertinoIcons.arrow_up_right,
  HomeWidgetType.cashflow => CupertinoIcons.arrow_right_arrow_left,
  HomeWidgetType.week => CupertinoIcons.chart_bar,
  HomeWidgetType.goals => CupertinoIcons.flag,
  HomeWidgetType.budgets => CupertinoIcons.gauge,
  HomeWidgetType.recent => CupertinoIcons.list_bullet,
  HomeWidgetType.quickAdd => CupertinoIcons.bolt,
};

/// Opens the editor of the widget of [type] on Inicio: size, colors, remove.
Future<void> showHomeWidgetSheet(BuildContext context, HomeWidgetType type) =>
    showModalBottomSheet<void>(
      sheetAnimationStyle: Motion.sheet,
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HomeWidgetSheet(type: type),
    );

/// Chooses, orders and styles the widgets of Inicio, and the phone's
/// home-screen widget.
class CustomizeHomeScreen extends ConsumerWidget {
  const CustomizeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    final dashboard = ref.watch(dashboardProvider);
    final available = [
      for (final type in HomeWidgetType.values)
        if (!layout.any((c) => c.type == type)) type,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.paddingOf(context).bottom + 28,
              ),
              children: [
                Row(
                  children: [
                    CircleButton(
                      icon: CupertinoIcons.chevron_left,
                      tooltip: 'Volver',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LargeTitle(
                  title: 'Tu inicio',
                  subtitle: 'Elige, ordena y dale color a tus widgets',
                  trailing: [
                    CircleButton(
                      icon: CupertinoIcons.arrow_counterclockwise,
                      tooltip: 'Restablecer',
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: '¿Restablecer tu inicio?',
                          message: 'Volverán los widgets y colores de siempre.',
                          confirmLabel: 'Restablecer',
                        );
                        if (ok) {
                          ref.read(homeLayoutProvider.notifier).reset();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const FadeSlideIn(child: SectionHeader(title: 'En tu inicio')),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 1,
                  child: layout.isEmpty
                      ? BentoCard(
                          child: Text(
                            'No hay widgets. Añade alguno de abajo.',
                            style: TextStyle(color: context.palette.muted),
                          ),
                        )
                      : _CurrentWidgets(layout: layout),
                ),
                if (available.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const FadeSlideIn(
                    index: 2,
                    child: SectionHeader(title: 'Añadir widgets'),
                  ),
                  const SizedBox(height: 8),
                  for (final (i, type) in available.indexed) ...[
                    if (i > 0) const SizedBox(height: 14),
                    FadeSlideIn(
                      index: 3 + i,
                      child: _GalleryItem(type: type, data: dashboard.value),
                    ),
                  ],
                ],
                const SizedBox(height: 28),
                const FadeSlideIn(index: 4, child: PhoneWidgetSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentWidgets extends ConsumerWidget {
  const _CurrentWidgets({required this.layout});

  final List<HomeWidgetConfig> layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return BentoCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      radius: 18,
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorderItem: ref.read(homeLayoutProvider.notifier).reorder,
        proxyDecorator: (child, _, _) => Material(
          color: palette.card,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
        children: [
          for (final (i, config) in layout.indexed)
            ListTile(
              key: ValueKey(config.type),
              onTap: () => showHomeWidgetSheet(context, config.type),
              contentPadding: const EdgeInsets.only(left: 6, right: 14),
              minTileHeight: 60,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Quitar ${config.type.label}',
                    onPressed: () => ref
                        .read(homeLayoutProvider.notifier)
                        .remove(config.type),
                    icon: Icon(
                      CupertinoIcons.minus_circle_fill,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  _StyleChip(config: config),
                ],
              ),
              title: Text(
                config.type.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${config.size.label} · ${config.style.label}',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              trailing: ReorderableDragStartListener(
                index: i,
                child: Tooltip(
                  message: 'Mover ${config.type.label}',
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      CupertinoIcons.line_horizontal_3,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The widget's icon on its own colors.
class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.config});

  final HomeWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final tone = HomeTone.of(context, config.style);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tone.background,
        gradient: tone.gradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Icon(
        homeWidgetIcon(config.type),
        size: 18,
        color: tone.foreground,
      ),
    );
  }
}

/// A widget as it would look with real data; not interactive.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.config, required this.data});

  final HomeWidgetConfig config;
  final DashboardData? data;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    if (data == null) return const SizedBox(height: 120, child: AppShimmer());
    final card = ExcludeSemantics(
      child: IgnorePointer(
        child: HomeCard(config: config, data: data),
      ),
    );
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: config.compact
          ? Center(
              child: SizedBox(width: _compactPreviewWidth, child: card),
            )
          : card,
    );
  }
}

class _GalleryItem extends ConsumerWidget {
  const _GalleryItem({required this.type, required this.data});

  final HomeWidgetType type;
  final DashboardData? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return BentoCard(
      border: true,
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LivePreview(config: HomeWidgetConfig.of(type), data: data),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      type.description,
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleButton(
                icon: CupertinoIcons.add,
                tooltip: 'Añadir ${type.label}',
                filled: true,
                onPressed: () =>
                    ref.read(homeLayoutProvider.notifier).add(type),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeWidgetSheet extends ConsumerWidget {
  const _HomeWidgetSheet({required this.type});

  final HomeWidgetType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .watch(homeLayoutProvider)
        .where((c) => c.type == type)
        .firstOrNull;
    // Removed from Inicio while the sheet was open.
    if (config == null) return const SizedBox.shrink();
    final controller = ref.read(homeLayoutProvider.notifier);
    final palette = context.palette;
    final label = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: palette.muted);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(type.label, style: Theme.of(context).textTheme.titleLarge),
          Text(type.description, style: TextStyle(color: palette.muted)),
          const SizedBox(height: 18),
          _LivePreview(
            config: config,
            data: ref.watch(dashboardProvider).value,
          ),
          if (type.sizes.length > 1) ...[
            const SizedBox(height: 20),
            Text('Tamaño', style: label),
            const SizedBox(height: 8),
            SegmentedTabs<HomeWidgetSize>(
              selected: config.size,
              onChanged: (size) => controller.edit(type, size: size),
              segments: {for (final s in type.sizes) s: s.label},
            ),
          ],
          if (type.styles.length > 1) ...[
            const SizedBox(height: 20),
            Text('Color', style: label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final style in type.styles)
                  _Swatch(
                    style: style,
                    selected: style == config.style,
                    onTap: () => controller.edit(type, style: style),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
          const SizedBox(height: 6),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              controller.remove(type);
              Navigator.pop(context);
            },
            child: const Text('Quitar del inicio'),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final HomeWidgetStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = HomeTone.of(context, style);
    final ring = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label: style.label,
      child: Tooltip(
        message: style.label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
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
                color: tone.background,
                gradient: tone.gradient,
              ),
              child: selected
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 20,
                      color: tone.foreground,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
