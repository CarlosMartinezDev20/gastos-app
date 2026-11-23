import 'package:appgastos/core/errors/api_exception.dart';
import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/screens/new_transaction_sheet.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:appgastos/core/utils/phone_widget.dart';
import 'package:appgastos/models/dashboard.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('a draft survives app disposal and is removed after saving', (
    tester,
  ) async {
    final drafts = FakeTransactionDraftStore();
    await flow.pumpApp(tester, drafts: drafts);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '12.5');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Borrador persistente',
    );
    await flow.selectExpenseCategory(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(drafts.drafts.values.single['title'], 'Borrador persistente');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final backend = await flow.pumpApp(tester, drafts: drafts);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador persistente'), findsOneWidget);
    expect(find.textContaining('Borrador recuperado'), findsOneWidget);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.transactions.last.title, 'Borrador persistente');
    expect(drafts.drafts, isEmpty);
  });

  testWidgets('explicitly discarding a draft removes its stored copy', (
    tester,
  ) async {
    final drafts = FakeTransactionDraftStore();
    await flow.pumpApp(tester, drafts: drafts);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Descartar',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Descartar'));
    await tester.pumpAndSettle();
    expect(drafts.drafts, isEmpty);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar'), findsNothing);
  });

  testWidgets(
    'register similar creates a fresh movement without editing the original',
    (tester) async {
      final backend = await flow.pumpApp(tester);
      final original = backend.transactions.firstWhere(
        (t) => t.type == TransactionType.expense && !t.isGoalContribution,
      );
      await flow.goToTab(tester, 'Historial');
      await flow.scrollTo(tester, find.text(original.title));
      await tester.tap(find.text(original.title));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Registrar uno similar'));
      await tester.tap(find.text('Registrar uno similar'));
      await tester.pumpAndSettle();
      expect(find.byType(NewTransactionSheet), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Descripción'),
            )
            .controller!
            .text,
        original.title,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '7.25',
      );
      await tester.tap(find.text('Guardar gasto'));
      await tester.pumpAndSettle();
      expect(backend.transactions.last.amount, 7.25);
      expect(backend.transactions.last.id, isNot(original.id));
      expect(
        backend.transactions.firstWhere((t) => t.id == original.id).amount,
        original.amount,
      );
      expect(backend.transactions.last.reference, isNull);
    },
  );

  testWidgets('save failure keeps the draft and allows retry', (tester) async {
    final drafts = FakeTransactionDraftStore();
    final backend = await flow.pumpApp(tester, drafts: drafts);
    backend.saveError = const ApiException('Sin conexión');
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '3');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Reintentar',
    );
    await flow.selectExpenseCategory(tester);
    await tester.tap(find.text('Guardar gasto'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
    expect(drafts.drafts, isNotEmpty);
    backend.saveError = null;
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(drafts.drafts, isEmpty);
  });

  testWidgets(
    'privacy hides currency in every main destination and input amounts',
    (tester) async {
      await flow.pumpApp(tester);
      await tester.tap(find.byTooltip('Ocultar importes'));
      await tester.pumpAndSettle();
      void expectNoAmounts() {
        final painted = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((text) => text.text.toPlainText())
            .join('\n');
        expect(
          RegExp(r'\$\s*-?\d').hasMatch(painted),
          isFalse,
          reason: painted,
        );
      }

      expectNoAmounts();
      for (final tab in ['Historial', 'Metas', 'Análisis']) {
        await flow.goToTab(tester, tab);
        expectNoAmounts();
      }
      await tester.tap(find.byTooltip('Registrar movimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '123.45',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.widgetWithText(TextFormField, 'Monto'),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isTrue,
      );
      expectNoAmounts();
    },
  );

  testWidgets(
    'the balance explanation distinguishes net outflows and reserved savings',
    (tester) async {
      await flow.pumpApp(tester);
      await tester.tap(find.byTooltip('Cómo se calcula el balance'));
      await tester.pumpAndSettle();
      expect(find.text('Cómo se calcula tu balance'), findsOneWidget);
      expect(find.text('Salidas netas registradas'), findsOneWidget);
      expect(find.text('Apartado en metas'), findsOneWidget);
      expect(find.textContaining('No se descuenta otra vez'), findsOneWidget);
      expect(find.text(r'$141.50'), findsWidgets);
    },
  );

  test('phone widget privacy covers every content mode and caption', () {
    final backend = FakeBackend();
    final data = DashboardData(
      user: daniela,
      balance: const BalanceSummary(
        totalIncome: 200,
        totalExpense: 58.5,
        balance: 141.5,
      ),
      transactions: backend.transactions,
      goals: backend.goals,
    );
    for (final content in PhoneWidgetContent.values) {
      final payload = phoneWidgetPayload(
        data,
        content: content,
        theme: PhoneWidgetTheme.dark,
        balanceHidden: true,
        now: DateTime(2026, 10, 31),
      );
      expect(
        RegExp(r'\$\s*\d').hasMatch('${payload.amount} ${payload.caption}'),
        isFalse,
      );
      expect(payload.bars, isEmpty);
    }
  });

  testWidgets(
    'validation focuses the missing description and a keyboard-selectable category',
    (tester) async {
      await flow.pumpApp(tester);
      await tester.tap(find.byTooltip('Registrar movimiento'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '4');
      await tester.tap(find.text('Guardar gasto'));
      await tester.pumpAndSettle();
      final description = find.descendant(
        of: find.widgetWithText(TextFormField, 'Descripción'),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(description).focusNode.hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Teclado',
      );
      await tester.tap(find.text('Guardar gasto'));
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(ChoiceChip, 'Comida');
      expect(tester.widget<ChoiceChip>(chip).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    },
  );

  testWidgets('privacy control exposes its action to assistive technology', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await flow.pumpApp(tester);
      expect(find.bySemanticsLabel(RegExp('Ocultar importes')), findsWidgets);
      await tester.tap(find.byTooltip('Ocultar importes'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Mostrar importes')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp(r'\$141\.50')), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'restored draft and save action fit large text with the keyboard open',
    (tester) async {
      final drafts = FakeTransactionDraftStore();
      await drafts.write('transaction_draft_v1:${daniela.id}:new', {
        'version': 1,
        'title': 'Borrador accesible',
        'amount': '4',
        'type': 'expense',
        'date': DateTime.now().toIso8601String(),
        'categoryId': food.id,
        'paymentMethodId': null,
        'methodPicked': false,
        'reference': null,
        'repeat': null,
      });
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await flow.pumpApp(tester, drafts: drafts, size: const Size(320, 740));
      await tester.tap(find.byTooltip('Registrar movimiento'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.textContaining('Borrador recuperado'), findsOneWidget);
      expect(find.text('Guardar gasto').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
