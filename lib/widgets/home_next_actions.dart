import 'money_privacy.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/home_attention.dart';
import '../models/category.dart';
import '../providers/finance_providers.dart';
import '../screens/budget_sheet.dart';
import '../screens/new_goal_sheet.dart';
import '../screens/new_transaction_sheet.dart';
import '../screens/subscription_sheet.dart';
import '../screens/wallet_screen.dart';
import 'ios_ui.dart';

class HomeNextActions extends ConsumerWidget {
  const HomeNextActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = homeAttention(
      budgets: ref.watch(budgetsProvider).value ?? const [],
      recurring: ref.watch(recurringProvider).value ?? const [],
      methods: ref.watch(paymentMethodsProvider).value ?? const [],
      now: DateTime.now(),
    );
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Para revisar'),
          const SizedBox(height: 8),
          InsetGroup(
            children: [
              for (final item in items)
                InsetTile(
                  icon: item.budget != null
                      ? CupertinoIcons.chart_pie
                      : CupertinoIcons.calendar,
                  title: item.title,
                  subtitle: context.privateMoneyText(item.detail),
                  onTap: () {
                    if (item.budget case final budget?) {
                      showBudgetSheet(context, budget: budget);
                    } else if (item.method case final method?) {
                      showWalletDetail(context, method.id);
                    } else if (item.rule case final rule?) {
                      if (rule.isSubscription) {
                        showSubscriptionSheet(context, rule: rule);
                      } else {
                        context.push('/recurring');
                      }
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeGettingStarted extends StatelessWidget {
  const HomeGettingStarted({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Empieza con tu primer movimiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Registra lo que recibes o gastas. Después puedes organizarlo con presupuestos y metas.',
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showNewTransactionSheet(
              context,
              initialType: TransactionType.expense,
            ),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Registra tu primer movimiento'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => showBudgetSheet(context),
                child: const Text('Crear presupuesto'),
              ),
              TextButton(
                onPressed: () => showNewGoalSheet(context),
                child: const Text('Crear meta'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
