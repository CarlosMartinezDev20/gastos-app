import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/core/utils/transaction_suggestions.dart';
import 'package:appgastos/core/utils/formatters.dart';
import 'package:appgastos/providers/auth_provider.dart';
import 'package:appgastos/providers/finance_providers.dart';
import 'package:appgastos/providers/history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/budget.dart';
import 'package:appgastos/models/recurring.dart';
import 'package:appgastos/core/utils/home_attention.dart';
import 'package:appgastos/screens/home_screen.dart';
import 'package:appgastos/screens/new_transaction_sheet.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_flow_test.dart' as flow;
import 'support/fakes.dart';

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    Mascot.animate = false;
    WidgetController.hitTestWarningShouldBeFatal = true;
    await initializeDateFormatting('es');
  });

  test('suggestions respect movement type and existing categories', () {
    final history = FakeBackend().transactions;
    expect(
      suggestedCategory(
        title: '',
        type: TransactionType.expense,
        categories: [food, salary],
        history: history,
      )?.id,
      food.id,
    );
    expect(
      suggestedCategory(
        title: 'TUTORÍAS',
        type: TransactionType.income,
        categories: [food, salary],
        history: history,
      )?.id,
      salary.id,
    );
    expect(
      suggestedCategory(
        title: 'Otra compra',
        type: TransactionType.expense,
        categories: [food, salary],
        history: history,
      ),
      isNull,
    );
    expect(
      suggestedCategory(
        title: '',
        type: TransactionType.expense,
        categories: [salary],
        history: history,
      ),
      isNull,
    );
  });

  test(
    'payment suggestions prefer the same description and ignore deleted methods',
    () {
      const card = PaymentMethod(
        id: 'card',
        name: 'Tarjeta',
        kind: PaymentMethodKind.debitCard,
        color: 'ocean',
      );
      const cash = PaymentMethod(
        id: 'cash',
        name: 'Efectivo',
        kind: PaymentMethodKind.cash,
        color: 'ocean',
      );
      final history = [
        Transaction(
          id: '1',
          title: 'Café',
          amount: 3,
          type: TransactionType.expense,
          date: DateTime(2026, 10, 1),
          category: food,
          paymentMethodId: 'card',
        ),
        Transaction(
          id: '2',
          title: 'Bus',
          amount: 1,
          type: TransactionType.expense,
          date: DateTime(2026, 10, 2),
          category: food,
          paymentMethodId: 'cash',
        ),
      ];
      expect(
        suggestedPaymentMethod(
          title: 'cafe',
          type: TransactionType.expense,
          methods: [card, cash],
          history: history,
        ),
        'card',
      );
      expect(
        suggestedPaymentMethod(
          title: 'cafe',
          type: TransactionType.expense,
          methods: [cash],
          history: history,
        ),
        'cash',
      );
      expect(
        suggestedPaymentMethod(
          title: 'cafe',
          type: TransactionType.income,
          methods: [card, cash],
          history: history,
        ),
        isNull,
      );
    },
  );

  testWidgets('a category suggestion is accepted explicitly', (tester) async {
    await flow.pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    final category = find.widgetWithText(ChoiceChip, 'Comida');
    expect(tester.widget<ChoiceChip>(category).selected, isFalse);
    expect(find.text('Sugerida'), findsOneWidget);
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(category).selected, isTrue);
    expect(find.text('Sugerida'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Otra compra',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(category).selected, isTrue);
  });
  test('date ranges keep the year and month boundaries visible', () {
    expect(
      Formatters.dateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      '1–31 oct 2026',
    );
    expect(
      Formatters.dateRange(DateTime(2025, 12, 30), DateTime(2026, 1, 2)),
      '30 dic 2025 – 2 ene 2026',
    );
  });

  test(
    'card filters include matching movements beyond the first page',
    () async {
      final backend = FakeBackend(withData: false);
      backend.transactions.addAll(
        List.generate(
          80,
          (i) => Transaction(
            id: 'tx$i',
            title: 'Compra $i',
            amount: 2,
            type: TransactionType.expense,
            date: DateTime(2026, 10, 1, 23, 59),
            category: food,
            paymentMethodId: i.isEven ? 'card' : 'cash',
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          financeRepositoryProvider.overrideWithValue(
            FakeFinanceRepository(backend),
          ),
        ],
      );
      addTearDown(container.dispose);
      final query = (
        search: '',
        type: TransactionType.expense,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 1),
        categoryId: food.id,
        paymentMethodId: 'card',
      );
      final subscription = container.listen(
        historyProvider(query),
        (_, next) {},
      );
      addTearDown(subscription.close);
      final result = await container.read(historyProvider(query).future);
      expect(result.items, hasLength(40));
      expect(result.summary.count, 40);
      expect(result.summary.expense, 80);
      expect(result.hasMore, isFalse);
    },
  );

  testWidgets(
    'history filters, totals and CSV use the same category and card',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final backend = await flow.pumpApp(tester);
      backend.paymentMethods.add(
        const PaymentMethod(
          id: 'card',
          name: 'Débito',
          kind: PaymentMethodKind.debitCard,
          color: 'ocean',
          last4: '1234',
        ),
      );
      backend.transactions.addAll([
        Transaction(
          id: 'card-tx',
          title: 'Café con tarjeta',
          amount: 3,
          type: TransactionType.expense,
          date: DateTime.now(),
          category: food,
          paymentMethodId: 'card',
        ),
        Transaction(
          id: 'cash-tx',
          title: 'Café en efectivo',
          amount: 2,
          type: TransactionType.expense,
          date: DateTime.now(),
          category: food,
        ),
      ]);
      await flow.refreshBackend(tester);
      await flow.goToTab(tester, 'Historial');
      await tester.tap(find.text('Categoría y tarjeta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comida').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Débito ··1234').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Café con tarjeta'), findsOneWidget);
      expect(find.text('Café en efectivo'), findsNothing);
      expect(find.textContaining('1 movimiento ·'), findsOneWidget);
      await tester.tap(find.byTooltip('Exportar CSV'));
      await tester.pumpAndSettle();
      expect(copied, contains('Café con tarjeta'));
      expect(copied, isNot(contains('Café en efectivo')));
      await tester.tap(find.byTooltip('Quitar filtro de tarjeta'));
      await tester.pumpAndSettle();
      expect(find.text('Café en efectivo'), findsOneWidget);
    },
  );
  test(
    'home attention uses actual limits and active payments within seven days',
    () {
      final now = DateTime(2026, 10, 20);
      RecurringRule rule(
        String id,
        int day, {
        bool active = true,
        TransactionType type = TransactionType.expense,
      }) => RecurringRule(
        id: id,
        title: id,
        amount: 10,
        type: type,
        category: food,
        frequency: RecurrenceFrequency.monthly,
        nextDate: DateTime(2026, 10, day),
        active: active,
      );
      final items = homeAttention(
        budgets: [Budget(category: food, amount: 100, spent: 85)],
        recurring: [
          rule('hoy', 20),
          rule('proxima', 23),
          rule('pasada', 19),
          rule('pausada', 21, active: false),
          rule('lejana', 28),
          rule('ingreso', 20, type: TransactionType.income),
        ],
        methods: [],
        now: now,
      );
      expect(items.map((item) => item.id), [
        'rule-hoy',
        'rule-proxima',
        'budget-${food.id}',
      ]);
      expect(items.first.title, 'hoy: hoy');
      expect(
        homeAttention(
          budgets: [Budget(category: food, amount: 0, spent: 2)],
          recurring: [],
          methods: [],
          now: now,
        ),
        isEmpty,
      );
    },
  );

  test('paid cards do not create payment alerts', () {
    final now = DateTime(2026, 10, 20);
    const method = PaymentMethod(
      id: 'paid',
      name: 'Crédito',
      kind: PaymentMethodKind.creditCard,
      color: 'ocean',
      dueDay: 20,
      chargedTotal: 100,
      paidTotal: 100,
    );
    expect(
      homeAttention(budgets: [], recurring: [], methods: [method], now: now),
      isEmpty,
    );
  });

  testWidgets(
    'a new account has a clear first action opening the draggable panel',
    (tester) async {
      await flow.pumpApp(tester, withData: false);
      expect(find.text('Empieza con tu primer movimiento'), findsOneWidget);
      await tester.tap(find.text('Registra tu primer movimiento'));
      await tester.pumpAndSettle();
      expect(find.byType(NewTransactionSheet), findsOneWidget);
      expect(
        tester
            .widgetList<BottomSheet>(find.byType(BottomSheet))
            .any((sheet) => sheet.enableDrag && sheet.showDragHandle == true),
        isTrue,
      );
    },
  );

  testWidgets('a budget notice opens its existing detail directly', (
    tester,
  ) async {
    final backend = await flow.pumpApp(tester);
    backend.budgets[food.id] = 10;
    backend.transactions.add(
      Transaction(
        id: 'recent-budget',
        title: 'Comida de hoy',
        amount: 9,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container.invalidate(budgetsProvider);
    await tester.pumpAndSettle();
    expect(find.text('Comida: cerca del límite'), findsOneWidget);
    await tester.tap(find.text('Comida: cerca del límite'));
    await tester.pumpAndSettle();
    expect(find.text('Editar presupuesto'), findsOneWidget);
  });
  testWidgets('first use and filters fit a narrow screen with large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await flow.pumpApp(tester, withData: false, size: const Size(320, 740));
    await tester.ensureVisible(find.text('Registra tu primer movimiento'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await flow.goToTab(tester, 'Historial');
    await Scrollable.ensureVisible(
      tester.element(find.text('Categoría y tarjeta')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoría y tarjeta'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar filtros').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
