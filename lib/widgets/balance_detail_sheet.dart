import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../models/dashboard.dart';
import '../providers/finance_providers.dart';
import 'money_privacy.dart';

Future<void> showBalanceDetail(BuildContext context, DashboardData data) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BalanceDetail(data: data),
    );

class _BalanceDetail extends ConsumerWidget {
  const _BalanceDetail({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final saved = data.goals.fold(0.0, (sum, goal) => sum + goal.savedAmount);
    final debt = (methods.value ?? const [])
        .where((m) => m.kind.isCredit)
        .fold(
          0.0,
          (sum, m) =>
              sum +
              (m.chargedTotal - m.paidTotal > 0
                  ? m.chargedTotal - m.paidTotal
                  : 0),
        );
    Widget fact(String title, num value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 4,
        children: [
          Text(title),
          Text(
            context.money(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cómo se calcula tu balance',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Todos tus movimientos registrados',
            style: TextStyle(color: context.palette.muted),
          ),
          const SizedBox(height: 12),
          fact('Ingresos registrados', data.balance.totalIncome),
          fact('Salidas netas registradas', data.balance.totalExpense),
          const Divider(),
          fact('Balance disponible', data.balance.balance),
          const SizedBox(height: 8),
          const Text(
            'Balance = ingresos − salidas netas. Las salidas incluyen los aportes a metas; los retiros de metas las reducen.',
          ),
          const SizedBox(height: 20),
          fact('Apartado en metas', saved),
          const Text(
            'Este dinero ya salió del balance disponible. No se descuenta otra vez.',
          ),
          const SizedBox(height: 12),
          if (methods.hasValue) ...[
            fact('Deuda total de tarjetas', debt),
            const Text(
              'Las compras registradas ya afectan el balance. La deuda se muestra aparte y no se vuelve a restar; tampoco equivale al pago mínimo.',
            ),
          ] else if (methods.hasError)
            TextButton(
              onPressed: () => ref.invalidate(paymentMethodsProvider),
              child: const Text('Reintentar cargar tarjetas'),
            )
          else
            const LinearProgressIndicator(),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
