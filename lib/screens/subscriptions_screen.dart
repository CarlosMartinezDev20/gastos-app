import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/formatters.dart';
import '../core/utils/subscriptions.dart';
import '../core/utils/wallet.dart';
import '../models/recurring.dart';
import '../providers/finance_providers.dart';
import '../widgets/app_states.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import '../widgets/service_logo.dart';
import 'subscription_sheet.dart';

/// Opens the catalog and then the form for the chosen service.
Future<void> addSubscription(BuildContext context) async {
  final key = await showServicePicker(context);
  if (key != null && context.mounted) {
    await showSubscriptionSheet(context, serviceKey: key);
  }
}

/// "Suscripciones": the recurring expenses tied to a service (ChatGPT,
/// Spotify…), what they cost per month and year, and when each one charges.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(recurringProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            : context.go('/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LargeTitle(
                    title: 'Suscripciones',
                    subtitle: 'Lo que pagas sin pensarlo, cada mes',
                    trailing: [
                      CircleButton(
                        icon: CupertinoIcons.add,
                        tooltip: 'Agregar suscripción',
                        filled: true,
                        onPressed: () => addSubscription(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...rules.when(
                    loading: () => const [
                      SizedBox(height: 160, child: AppShimmer()),
                    ],
                    error: (error, _) => [
                      AppErrorState(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(recurringProvider),
                      ),
                    ],
                    data: (all) {
                      final subs = all.where((r) => r.isSubscription).toList();
                      if (subs.isEmpty) return const [_EmptySubscriptions()];
                      final active = upcomingCharges(subs);
                      final paused = subs.where((s) => !s.active).toList();
                      return [
                        FadeSlideIn(child: _TotalCard(subscriptions: subs)),
                        if (active.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Próximos cobros'),
                          const SizedBox(height: 8),
                          FadeSlideIn(
                            index: 1,
                            child: _SubscriptionList(subscriptions: active),
                          ),
                        ],
                        if (paused.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'En pausa'),
                          const SizedBox(height: 8),
                          _SubscriptionList(subscriptions: paused),
                        ],
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.subscriptions});

  final List<RecurringRule> subscriptions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final monthly = monthlySubscriptionCost(subscriptions);
    final active = subscriptions.where((s) => s.active).length;
    return BentoCard(
      color: palette.ink,
      radius: 26,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PillTag(label: 'Al mes', color: palette.onInk),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.compactMoney(monthly),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: palette.onInk,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.compactMoney(monthly * 12)} al año · '
            '$active ${active == 1 ? 'activa' : 'activas'}',
            style: TextStyle(color: palette.inkMuted),
          ),
          const SizedBox(height: 16),
          // The logos of what you pay, overlapping like a stack of apps.
          SizedBox(
            height: 34,
            child: Stack(
              children: [
                for (final (i, s)
                    in subscriptions.where((s) => s.active).take(8).indexed)
                  Positioned(
                    left: i * 24.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: palette.ink, width: 2),
                      ),
                      child: ServiceLogo(
                        serviceKey: s.service,
                        name: s.title,
                        size: 30,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionList extends ConsumerWidget {
  const _SubscriptionList({required this.subscriptions});

  final List<RecurringRule> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    final palette = context.palette;
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, s) in subscriptions.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 76, color: palette.hairline),
            InkWell(
              onTap: () => showSubscriptionSheet(context, rule: s),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Opacity(
                      opacity: s.active ? 1 : .45,
                      child: ServiceLogo(serviceKey: s.service, name: s.title),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              s.frequency.label,
                              if (methods
                                      .where((m) => m.id == s.paymentMethodId)
                                      .firstOrNull
                                  case final method?)
                                method.shortLabel,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.compactMoney(s.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.active ? chargeLabel(s.nextDate) : 'En pausa',
                          style: TextStyle(
                            color: s.active && _soon(s.nextDate)
                                ? palette.onBlush
                                : palette.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _soon(DateTime date) =>
      daysUntil(date.toLocal(), DateTime.now()) <= 2;
}

class _EmptySubscriptions extends StatelessWidget {
  const _EmptySubscriptions();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Mascot(mood: MascotMood.happy, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todavía no tienes suscripciones',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Agrega ChatGPT, Spotify, Netflix… y te digo cuánto '
                      'suman y cuándo te cobran.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // A few popular ones, one tap away.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final key in ['chatgpt', 'claude', 'spotify', 'netflix'])
                Tooltip(
                  message: serviceFor(key)!.name,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        showSubscriptionSheet(context, serviceKey: key),
                    child: ServiceLogo(
                      serviceKey: key,
                      name: serviceFor(key)!.name,
                      size: 48,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => addSubscription(context),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Agregar suscripción'),
          ),
        ],
      ),
    );
  }
}
