import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/payment_method.dart';
import '../../models/recurring.dart';
import 'formatters.dart';
import 'wallet.dart';

class HomeAttention {
  const HomeAttention({
    required this.id,
    required this.title,
    required this.detail,
    required this.priority,
    required this.date,
    this.budget,
    this.rule,
    this.method,
  });

  final String id;
  final String title;
  final String detail;
  final int priority;
  final DateTime date;
  final Budget? budget;
  final RecurringRule? rule;
  final PaymentMethod? method;
}

/// Actual limits and upcoming payments, never invented alerts or future income.
List<HomeAttention> homeAttention({
  required List<Budget> budgets,
  required List<RecurringRule> recurring,
  required List<PaymentMethod> methods,
  required DateTime now,
}) {
  final items = <HomeAttention>[];
  for (final budget in budgets) {
    if (budget.amount <= 0 || (!budget.nearLimit && !budget.exceeded)) continue;
    items.add(
      HomeAttention(
        id: 'budget-${budget.categoryId}',
        title:
            '${budget.category.name}: ${budget.exceeded
                ? 'límite superado'
                : budget.spent == budget.amount
                ? 'límite alcanzado'
                : 'cerca del límite'}',
        detail:
            '${Formatters.compactMoney(budget.spent)} de ${Formatters.compactMoney(budget.amount)} este mes',
        priority: budget.exceeded ? 0 : 2,
        date: now,
        budget: budget,
      ),
    );
  }
  for (final rule in recurring) {
    if (!rule.active || rule.type != TransactionType.expense) continue;
    final due = rule.nextDate.toLocal();
    final days = daysUntil(due, now);
    if (days < 0 || days > 7) continue;
    items.add(
      HomeAttention(
        id: 'rule-${rule.id}',
        title: '${rule.title}: ${_when(days)}',
        detail:
            '${Formatters.compactMoney(rule.amount)} · ${Formatters.dayMonthYear.format(due)}',
        priority: days == 0
            ? 0
            : days <= 3
            ? 1
            : 2,
        date: due,
        rule: rule,
      ),
    );
  }
  for (final method in methods) {
    final debt = method.chargedTotal - method.paidTotal;
    if (!method.kind.isCredit || method.dueDay == null || debt <= .005) {
      continue;
    }
    final due = nextDueDate(method.dueDay!, now);
    final days = daysUntil(due, now);
    if (days > 7) continue;
    items.add(
      HomeAttention(
        id: 'method-${method.id}',
        title: '${method.shortLabel}: pago ${_when(days)}',
        detail: 'Saldo total pendiente: ${Formatters.compactMoney(debt)}',
        priority: days == 0
            ? 0
            : days <= 3
            ? 1
            : 2,
        date: due,
        method: method,
      ),
    );
  }
  items.sort((a, b) {
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.id.compareTo(b.id);
  });
  return items.take(3).toList();
}

String _when(int days) => switch (days) {
  0 => 'hoy',
  1 => 'mañana',
  _ => 'en $days días',
};
