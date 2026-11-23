import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:appgastos/screens/new_transaction_sheet.dart';
import 'package:appgastos/screens/transactions_screen.dart';
import 'package:appgastos/widgets/goal_icon_picker.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:appgastos/widgets/transaction_category_picker.dart';
import 'package:appgastos/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_flow_test.dart' as flow;

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    AppTheme.useGoogleFonts = false;
    Mascot.animate = false;
    await initializeDateFormatting('es');
  });

  testWidgets('requires a category before saving a new movement', (
    tester,
  ) async {
    final backend = await flow.pumpApp(tester);
    final count = backend.transactions.length;
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Comida'))
          .selected,
      isFalse,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '4.5');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Café',
    );
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.transactions, hasLength(count));
    expect(find.text('Selecciona una categoría'), findsOneWidget);
    await flow.selectExpenseCategory(tester);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.transactions, hasLength(count + 1));
    expect(find.byType(NewTransactionSheet), findsNothing);
    expect(find.text('¿Descartar los cambios?'), findsNothing);
  });

  testWidgets('closing an untouched movement does not ask to discard', (
    tester,
  ) async {
    await flow.pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    expect(find.byType(NewTransactionSheet), findsNothing);
    expect(find.text('¿Descartar los cambios?'), findsNothing);
  });

  for (final income in [false, true]) {
    testWidgets(
      'the ${income ? 'income' : 'expense'} panel can be dragged closed',
      (tester) async {
        await flow.pumpApp(tester);
        await tester.tap(
          income
              ? find.text('Registrar ingreso')
              : find.byTooltip('Registrar movimiento'),
        );
        await tester.pumpAndSettle();
        final panel = find.byType(BottomSheet).last;
        final bounds = tester.getRect(panel);
        await tester.dragFrom(
          Offset(bounds.center.dx, bounds.top + 16),
          const Offset(0, 600),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NewTransactionSheet), findsNothing);
        expect(find.text('¿Descartar los cambios?'), findsNothing);
      },
    );
  }

  testWidgets('dragging a dirty panel asks before losing the draft', (
    tester,
  ) async {
    await flow.pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Borrador arrastrable',
    );
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(BottomSheet).last);
    await tester.dragFrom(
      Offset(bounds.center.dx, bounds.top + 16),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador arrastrable'), findsOneWidget);
    expect(find.text('Guardar gasto').hitTestable(), findsOneWidget);
    final restoredBounds = tester.getRect(find.byType(BottomSheet).last);
    await tester.dragFrom(
      Offset(restoredBounds.center.dx, restoredBounds.top + 16),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(NewTransactionSheet), findsNothing);
  });

  testWidgets('changing movement type requires choosing its category', (
    tester,
  ) async {
    await flow.pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await flow.selectExpenseCategory(tester);
    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Comida'), findsNothing);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Trabajo'))
          .selected,
      isFalse,
    );
    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Comida'))
          .selected,
      isFalse,
    );
  });

  testWidgets('a goal sheet confirms before discarding edits', (tester) async {
    final backend = await flow.pumpApp(tester);
    final count = backend.goals.length;
    await flow.goToTab(tester, 'Metas');
    await tester.tap(find.byTooltip('Nueva meta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la meta'),
      'Borrador',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(backend.goals, hasLength(count));
    expect(find.text('Nombre de la meta'), findsNothing);
  });

  testWidgets('closing a dirty movement preserves edits until discarded', (
    tester,
  ) async {
    final backend = await flow.pumpApp(tester);
    final count = backend.transactions.length;
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Borrador',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(NewTransactionSheet), findsNothing);
    expect(backend.transactions, hasLength(count));
  });

  for (final entry in [
    ('Ingresos', TransactionType.income),
    ('Gastos', TransactionType.expense),
  ]) {
    testWidgets('${entry.$1} opens the matching 30-day history', (
      tester,
    ) async {
      final backend = await flow.pumpApp(tester);
      final now = DateTime.now();
      backend.transactions.addAll([
        for (final type in TransactionType.values)
          Transaction(
            id: 'recent-${type.name}',
            title: 'Reciente ${type.name}',
            amount: 10,
            type: type,
            date: now,
            category: backend.allCategories.firstWhere((c) => c.type == type),
          ),
        Transaction(
          id: 'old',
          title: 'Fuera del período',
          amount: 5,
          type: entry.$2,
          date: DateTime(now.year, now.month, now.day - 30),
          category: backend.allCategories.firstWhere((c) => c.type == entry.$2),
        ),
      ]);
      await tester.tap(find.text(entry.$1).first);
      await tester.pumpAndSettle();
      final screen = tester.widget<TransactionsScreen>(
        find.byType(TransactionsScreen),
      );
      expect(screen.initialType, entry.$2);
      expect(
        screen.initialRange!.start,
        DateTime(now.year, now.month, now.day - 29),
      );
      expect(screen.initialRange!.end, DateTime(now.year, now.month, now.day));
      final tiles = tester.widgetList<TransactionTile>(
        find.byType(TransactionTile),
      );
      expect(tiles, isNotEmpty);
      expect(tiles.every((tile) => tile.transaction.type == entry.$2), isTrue);
      expect(find.text('Fuera del período'), findsNothing);
      await flow.goToTab(tester, 'Inicio');
      await flow.goToTab(tester, 'Historial');
      expect(
        tester
            .widget<TransactionsScreen>(find.byType(TransactionsScreen))
            .initialType,
        isNull,
      );
    });
  }

  testWidgets('a goal keeps its fields when expanded to full screen', (
    tester,
  ) async {
    final backend = await flow.pumpApp(tester);
    await flow.goToTab(tester, 'Metas');
    await tester.tap(find.byTooltip('Nueva meta'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la meta'),
      'Viaje',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto objetivo'),
      '350',
    );
    await tester.tap(find.byTooltip('Pantalla completa'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Nombre de la meta'),
          )
          .controller!
          .text,
      'Viaje',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Monto objetivo'),
          )
          .controller!
          .text,
      '350',
    );
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    await flow.scrollTo(tester, find.text('Crear meta'));
    await tester.tap(find.text('Crear meta'));
    await tester.pumpAndSettle();
    expect(
      backend.goals.any((g) => g.name == 'Viaje' && g.targetAmount == 350),
      isTrue,
    );
    expect(find.text('¿Descartar los cambios?'), findsNothing);
  });

  testWidgets('many categories can be searched without hiding the selection', (
    tester,
  ) async {
    String? selected;
    final categories = List.generate(
      12,
      (i) => Category(
        id: 'c$i',
        name: 'Categoría $i',
        icon: 'restaurant',
        type: TransactionType.expense,
        isDefault: false,
        transactionCount: i,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: TransactionCategoryPicker(
                categories: categories,
                selected: selected,
                accent: Colors.green,
                onChanged: (id) => setState(() => selected = id),
                onCreate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    await tester.tap(find.text('Ver todas (12)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar categoría'),
      'categoria 0',
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Categoría 0'));
    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Categoría 0'), findsOneWidget);
    expect(selected, 'c0');
  });

  testWidgets('goal icon catalog preserves an uncommon selected icon', (
    tester,
  ) async {
    var selected = 'flight';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: GoalIconPicker(
                selected: selected,
                onChanged: (icon) => setState(() => selected = icon),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Emergencias'), findsNothing);
    await tester.tap(find.text('Ver todos los iconos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Emergencias'));
    await tester.tap(find.text('Emergencias'));
    await tester.ensureVisible(find.text('Ver menos iconos'));
    await tester.tap(find.text('Ver menos iconos'));
    await tester.pumpAndSettle();
    expect(selected, 'health_and_safety');
    expect(find.text('Emergencias'), findsOneWidget);
  });
}
