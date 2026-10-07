import '../../models/budget.dart';
import '../../models/metrics.dart';
import 'finance_insights.dart';
import 'formatters.dart';

/// How the mascot feels. Each mood has its own face and idle animation.
enum MascotMood { happy, excited, calm, worried, sleepy }

/// What the mascot says: a mood plus messages it cycles through on tap.
class MascotTip {
  const MascotTip(this.mood, this.messages);

  final MascotMood mood;
  final List<String> messages;
}

/// What the mascot says about this month's budgets: exceeded ones first,
/// then the ones close to their limit.
List<String> budgetMessages(List<Budget> budgets) => [
  for (final b in budgets.where((b) => b.exceeded))
    'Te pasaste del presupuesto de ${b.category.name} por '
        '${Formatters.compactMoney(-b.remaining)}.',
  for (final b in budgets.where((b) => b.nearLimit))
    'Ojo: ya usaste el ${(b.progress * 100).round()}% del presupuesto de '
        '${b.category.name}.',
];

/// Mascot reaction to the last 30 days of activity on the home screen.
MascotTip homeTip({
  required PeriodSummary month,
  required double balance,
  required bool hasActivity,
  required int goalCount,
  List<Budget> budgets = const [],
}) {
  const goalTip = 'Un aporte pequeño cada semana a tus metas suma mucho.';
  if (!hasActivity) {
    return const MascotTip(MascotMood.sleepy, [
      'Zzz… miau. Registra tu primer movimiento y me despierto.',
      'Toca el + para anotar un ingreso o un gasto.',
    ]);
  }
  if (balance < 0) {
    return const MascotTip(MascotMood.worried, [
      'Tu balance está en rojo. ¡Frenemos los gastos un poquito!',
      'Revisa en Análisis cuál es tu categoría más cara.',
    ]);
  }
  final budgetAlerts = budgetMessages(budgets);
  if (budgets.any((b) => b.exceeded)) {
    return MascotTip(MascotMood.worried, [
      ...budgetAlerts,
      'Revisa tus presupuestos en Análisis.',
    ]);
  }
  if (month.spent > month.income) {
    return MascotTip(MascotMood.worried, [
      'En 30 días gastaste ${Formatters.compactMoney(month.spent - month.income)} '
          'más de lo que ingresó.',
      'Revisa en Análisis cuál es tu categoría más cara.',
    ]);
  }
  final share = month.income == 0 ? 0.0 : month.spent / month.income;
  final percent = (share * 100).round();
  if (month.income > 0 && month.saved >= month.income * .1) {
    return MascotTip(MascotMood.excited, [
      '¡Ahorraste ${Formatters.compactMoney(month.saved)} en 30 días! Ronroneo de orgullo.',
      'Gastaste solo el $percent% de lo que ingresó.',
      goalTip,
    ]);
  }
  if (share <= .7) {
    return MascotTip(MascotMood.happy, [
      '¡Miau! Vas muy bien: gastaste el $percent% de tus ingresos.',
      if (goalCount == 0)
        'Crea una meta y guardamos juntos lo que sobra.'
      else
        goalTip,
    ]);
  }
  return MascotTip(MascotMood.calm, [
    'Gastaste el $percent% de lo que ingresó. ¡Cuidemos el resto!',
    goalTip,
  ]);
}

/// Mascot reading of the analysis screen.
MascotTip analysisTip(
  List<CategoryExpense> expenses,
  SavingsEfficiency efficiency, {
  List<Budget> budgets = const [],
}) {
  if (expenses.isEmpty && efficiency.totalIncome == 0) {
    return const MascotTip(MascotMood.sleepy, [
      'Aún no tengo datos para analizar. Registra algunos movimientos.',
    ]);
  }
  final sorted = [...expenses]..sort((a, b) => b.total.compareTo(a.total));
  final messages = <String>[
    ...budgetMessages(budgets),
    if (sorted.isNotEmpty)
      'Tu mayor gasto es ${sorted.first.categoryName}: '
          '${Formatters.compactMoney(sorted.first.total)} '
          '(${sorted.first.percentage.toStringAsFixed(0)}% del total).',
    if (sorted.isNotEmpty && sorted.first.percentage >= 50)
      'Más de la mitad se va en una sola categoría. Ahí está la mejor '
          'oportunidad de ahorro.',
    if (sorted.length >= 2)
      'Le sigue ${sorted[1].categoryName} con '
          '${Formatters.compactMoney(sorted[1].total)}.',
    if (efficiency.totalIncome > 0)
      'Guardaste el ${efficiency.efficiencyPercent.toStringAsFixed(0)}% de '
          'tus ingresos en metas. ${efficiency.message}'
    else
      'Registra tus ingresos para medir cuánto ahorras.',
  ];
  final mood = budgets.any((b) => b.exceeded)
      ? MascotMood.worried
      : efficiency.totalIncome == 0
      ? MascotMood.calm
      : efficiency.efficiencyPercent >= 25
      ? MascotMood.excited
      : efficiency.efficiencyPercent >= 10
      ? MascotMood.happy
      : efficiency.totalSaved == 0
      ? MascotMood.worried
      : MascotMood.calm;
  return MascotTip(mood, messages);
}
