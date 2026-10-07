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
import '../widgets/theme_toggle.dart';
import 'customize_home_screen.dart';

/// Content wider than this shows two columns.
const _twoColumnMinWidth = 760.0;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final layout = ref.watch(homeLayoutProvider);
    return dashboard.when(
      loading: () => const AppShimmer(),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(dashboardProvider.future),
          ref.refresh(budgetsProvider.future),
        ]),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumnMinWidth;
            final blocks = [
              for (final (i, block) in homeBlocks(layout).indexed)
                FadeSlideIn(
                  // A block keeps its state when the layout around it changes.
                  key: ValueKey(block.map((c) => c.type.name).join('+')),
                  index: i + 1,
                  child: _Block(configs: block, data: data),
                ),
            ];
            const gap = SizedBox(height: 14);

            return ListView(
              // Pull to refresh needs it even when the board is short.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 16, 20, dockClearance(context)),
              children: [
                FadeSlideIn(child: _Header(data: data)),
                const SizedBox(height: 24),
                if (blocks.isEmpty)
                  const _EmptyBoard()
                else if (wide)
                  // Two columns: blocks alternate between them, in order.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final column in [0, 1]) ...[
                        if (column == 1) const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: [
                              for (final (i, block) in blocks.indexed)
                                if (i % 2 == column) ...[if (i > 1) gap, block],
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  for (final (i, block) in blocks.indexed) ...[
                    if (i > 0) gap,
                    block,
                  ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/customize-home'),
                    icon: const Icon(CupertinoIcons.square_grid_2x2, size: 18),
                    label: const Text('Personalizar inicio'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A wide widget, or two compact ones side by side with the same height.
/// A long press edits the widget, like on a phone's home screen.
class _Block extends StatelessWidget {
  const _Block({required this.configs, required this.data});

  final List<HomeWidgetConfig> configs;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    Widget card(HomeWidgetConfig config) => GestureDetector(
      onLongPress: () => showHomeWidgetSheet(context, config.type),
      child: HomeCard(config: config, data: data),
    );
    if (configs.length == 1) return card(configs.single);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: card(configs[0])),
          const SizedBox(width: 12),
          Expanded(child: card(configs[1])),
        ],
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) => BentoCard(
    child: Column(
      children: [
        const AppEmptyState(
          title: 'Tu inicio está vacío',
          subtitle: 'Elige qué quieres ver aquí.',
        ),
        FilledButton.icon(
          onPressed: () => context.push('/customize-home'),
          icon: const Icon(CupertinoIcons.add),
          label: const Text('Añadir widgets'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DashboardData data;

  static String _greeting(DateTime now) => now.hour < 12
      ? 'Buenos días'
      : now.hour < 19
      ? 'Buenas tardes'
      : 'Buenas noches';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = data.user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((p) => p[0]).join().toUpperCase();
    final name = parts.isEmpty ? data.user.name : parts.first;

    final text = Theme.of(context).textTheme;
    // Greeting above, the name large below (like LargeTitle), so the name
    // has the whole width instead of sharing one line with the greeting.
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineMedium?.copyWith(
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CircleButton(
          icon: CupertinoIcons.square_grid_2x2,
          tooltip: 'Personalizar inicio',
          onPressed: () => context.push('/customize-home'),
        ),
        const SizedBox(width: 8),
        const ThemeToggle(),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Perfil',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/profile'),
            // Avatar with a lime ring, like the selected profile tab; as tall
            // as the buttons beside it.
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.accent, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: palette.pill,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: palette.onPill,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
