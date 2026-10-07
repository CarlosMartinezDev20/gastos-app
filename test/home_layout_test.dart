import 'package:appgastos/core/utils/home_layout.dart';
import 'package:appgastos/core/utils/phone_widget.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/dashboard.dart';
import 'package:appgastos/models/savings_goal.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

SavingsGoal goal(String name, double target, double saved) => SavingsGoal(
  id: name,
  name: name,
  targetAmount: target,
  savedAmount: saved,
  icon: 'flag',
  bgColor: '',
  iconColor: '',
  progressPercent: saved / target * 100,
);

void main() {
  const compact = HomeWidgetSize.compact;
  const wide = HomeWidgetSize.wide;

  test('a layout survives encoding and decoding', () {
    final layout = [
      HomeWidgetConfig.of(HomeWidgetType.week).copyWith(size: wide),
      const HomeWidgetConfig(
        HomeWidgetType.income,
        compact,
        HomeWidgetStyle.aurora,
      ),
    ];
    expect(decodeHomeLayout(encodeHomeLayout(layout)), layout);
  });

  test('decoding drops invalid entries and repeated types', () {
    expect(decodeHomeLayout(null), isNull);
    expect(decodeHomeLayout('no es json'), isNull);
    expect(decodeHomeLayout('{}'), isNull);
    final layout = decodeHomeLayout(
      '[{"type":"futuro"},'
      '{"type":"recent","size":"compact","style":"ink"},'
      '{"type":"income","size":"wide","style":"mint"},'
      '{"type":"income","size":"compact","style":"blush"}]',
    )!;
    // Sizes and styles the type doesn't allow fall back to its defaults.
    expect(layout, [
      const HomeWidgetConfig(HomeWidgetType.recent, wide, HomeWidgetStyle.card),
      const HomeWidgetConfig(
        HomeWidgetType.income,
        compact,
        HomeWidgetStyle.mint,
      ),
    ]);
  });

  test('consecutive compact widgets share a row, two at most', () {
    HomeWidgetConfig c(HomeWidgetType t) => HomeWidgetConfig.of(t);
    final blocks = homeBlocks([
      c(HomeWidgetType.balance),
      c(HomeWidgetType.income),
      c(HomeWidgetType.spending),
      c(HomeWidgetType.week),
      c(HomeWidgetType.recent),
      c(HomeWidgetType.goals),
    ]);
    expect(
      [for (final b in blocks) b.map((c) => c.type.name).join('+')],
      ['balance', 'income+spending', 'week', 'recent', 'goals'],
    );
  });

  test('the featured goal is the unfinished one closest to its target', () {
    expect(featuredGoalIndex([]), isNull);
    expect(
      featuredGoalIndex([
        (saved: 100, target: 100),
        (saved: 10, target: 100),
        (saved: 60, target: 100),
      ]),
      2,
    );
    expect(featuredGoalIndex([(saved: 5, target: 5)]), 0);
  });

  group('phone widget', () {
    final now = DateTime(2026, 10, 15, 18);
    DashboardData data({List<SavingsGoal> goals = const []}) => DashboardData(
      user: daniela,
      balance: const BalanceSummary(
        totalIncome: 300,
        totalExpense: 60,
        balance: 240,
      ),
      goals: goals,
      transactions: [
        Transaction(
          id: 'a',
          title: 'Bus',
          amount: 10,
          type: TransactionType.expense,
          date: DateTime(2026, 10, 13, 9),
          category: food,
        ),
        Transaction(
          id: 'b',
          title: 'Almuerzo',
          amount: 20,
          type: TransactionType.expense,
          date: DateTime(2026, 10, 15, 13),
          category: food,
        ),
      ],
    );

    test('shows the balance, or hides it like Inicio', () {
      final payload = phoneWidgetPayload(
        data(),
        content: PhoneWidgetContent.balance,
        theme: PhoneWidgetTheme.lime,
        balanceHidden: false,
        now: now,
      );
      expect(payload.amount, r'$240.00');
      expect(payload.caption, r'Gastos 30 días: $30.00');
      expect(payload.bars, [0, 0, 0, 0, .5, 0, 1]);
      expect(payload.toData(), containsPair('theme', 'lime'));
      expect(payload.toData(), containsPair('progress', -1));

      final hidden = phoneWidgetPayload(
        data(),
        content: PhoneWidgetContent.balance,
        theme: PhoneWidgetTheme.lime,
        balanceHidden: true,
        now: now,
      );
      expect(hidden.amount, '••••••');
    });

    test('shows the week and today', () {
      final payload = phoneWidgetPayload(
        data(),
        content: PhoneWidgetContent.week,
        theme: PhoneWidgetTheme.dark,
        balanceHidden: true,
        now: now,
      );
      expect(payload.amount, r'$30.00');
      expect(payload.caption, r'Hoy: $20.00');
    });

    test('shows the featured goal with its progress', () {
      PhoneWidgetPayload goalPayload(List<SavingsGoal> goals) =>
          phoneWidgetPayload(
            data(goals: goals),
            content: PhoneWidgetContent.goal,
            theme: PhoneWidgetTheme.light,
            balanceHidden: false,
            now: now,
          );
      expect(goalPayload([]).caption, 'Crea tu primera meta');
      final payload = goalPayload([
        goal('Bici', 200, 50),
        goal('Viaje', 100, 80),
      ]);
      expect(payload.title, 'Viaje');
      expect(payload.amount, '80%');
      expect(payload.progress, 80);
      expect(payload.bars, isEmpty);
    });
  });
}
