import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const Gap(14),
            Text(
              'Algo no cargó bien',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Gap(8),
            Text(message, textAlign: TextAlign.center),
            const Gap(18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const Gap(12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Gap(4),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface.withValues(alpha: .65)
        : Colors.white.withValues(alpha: .7);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            for (var index = 0; index < 6; index++) ...[
              Container(
                height: index == 0 ? 180 : 92,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              if (index != 5) const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}
