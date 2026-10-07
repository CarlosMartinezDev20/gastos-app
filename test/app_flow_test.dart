import 'package:appgastos/core/network/api_client.dart';
import 'package:appgastos/core/network/token_store.dart';
import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/main.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:appgastos/core/utils/receipt_scan.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/core/utils/budget_planner.dart';
import 'package:appgastos/providers/auth_provider.dart';
import 'package:appgastos/providers/finance_providers.dart';
import 'package:appgastos/providers/payment_reminders_provider.dart';
import 'package:appgastos/providers/phone_widget_provider.dart';
import 'package:appgastos/widgets/phone_widget_preview.dart';
import 'package:appgastos/providers/storage_provider.dart';
import 'package:appgastos/services/receipt_scanner.dart';
import 'package:appgastos/screens/category_sheet.dart';
import 'package:appgastos/widgets/ios_ui.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const phone = Size(390, 844);
const desktop = Size(1280, 800);

Future<FakeBackend> pumpApp(
  WidgetTester tester, {
  Size size = phone,
  bool loggedIn = true,
  bool withData = true,
  FakePhoneWidgetService? phoneWidget,
  ScanDraft? scan,
  FakePaymentReminderService? reminders,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final backend = FakeBackend(withData: withData);
  if (loggedIn) backend.token = 'token';
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // No Keystore in tests: the session lives in memory.
        tokenStoreProvider.overrideWithValue(
          MemoryTokenStore(loggedIn ? 'token' : null),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(backend)),
        financeRepositoryProvider.overrideWithValue(
          FakeFinanceRepository(backend),
        ),
        phoneWidgetServiceProvider.overrideWithValue(
          phoneWidget ?? FakePhoneWidgetService(),
        ),
        // No camera in tests: the scanner "reads" [scan].
        scanLauncherProvider.overrideWithValue((_) async => scan),
        paymentReminderServiceProvider.overrideWithValue(
          reminders ?? FakePaymentReminderService(),
        ),
      ],
      child: const AppGastosApp(),
    ),
  );
  await tester.pumpAndSettle();
  return backend;
}

/// The dock exposes the same destinations at every screen size.
Future<void> goToTab(WidgetTester tester, String label) async {
  final tooltip = find.byTooltip(label);
  await tester.tap(
    tooltip.evaluate().isNotEmpty ? tooltip.first : find.text(label).last,
  );
  await tester.pumpAndSettle();
}

/// Profile is accessible from the dock and the home avatar.
Future<void> openProfile(WidgetTester tester) async {
  if (find.byTooltip('Perfil').evaluate().isEmpty) {
    await goToTab(tester, 'Inicio');
  }
  await tester.tap(find.byTooltip('Perfil').first);
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  // Centered: at the top edge the collapsed title bar could cover it.
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: .5);
  await tester.pumpAndSettle();
}

/// Taps the back button at the top of a full-screen page.
Future<void> goBack(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byTooltip('Volver'),
    -300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byTooltip('Volver'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Volver'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // A tap that lands on another widget (e.g. a button hidden behind the
    // floating tab bar) must fail the test.
    WidgetController.hitTestWarningShouldBeFatal = true;
    AppTheme.useGoogleFonts = false;
    // The mascot's idle loop never settles.
    Mascot.animate = false;
    await initializeDateFormatting('es');
  });

  testWidgets('shows login without a session and signs in', (tester) async {
    final backend = await pumpApp(tester, loggedIn: false);
    await scrollTo(tester, find.text('Comenzar'));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'daniela@universidad.edu',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'incorrecta',
    );
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();
    expect(find.text('Credenciales inválidas'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'daniela123',
    );
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c == 'login'), hasLength(2));
    expect(find.text('Balance disponible'), findsOneWidget);
    expect(find.text(r'$141.50'), findsOneWidget);
  });

  testWidgets('the welcome page shrinks Michi to fit instead of scrolling', (
    tester,
  ) async {
    // Too short for the full-size card (the test font wraps more than a real
    // one), tall enough for a smaller one.
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    await pumpApp(tester, size: const Size(390, 1040), loggedIn: false);
    final hero = tester.getSize(find.byType(AspectRatio).first);
    expect(hero.height, lessThan(hero.width / 1.3));

    final cta = find.text('Comenzar');
    final before = tester.getTopLeft(cta);
    await tester.drag(cta, const Offset(0, -200));
    await tester.pump();
    expect(tester.getTopLeft(cta), before);
  });

  testWidgets('a page that fits does not move on drag', (tester) async {
    await pumpApp(tester, size: const Size(1280, 1600));
    await openProfile(tester);
    final title = find.text('Perfil').first;
    final before = tester.getTopLeft(title);
    await tester.drag(title, const Offset(0, 200));
    await tester.pump();
    expect(tester.getTopLeft(title), before);
  });

  testWidgets('a short page can still be pulled to refresh', (tester) async {
    await pumpApp(tester, size: desktop, withData: false);
    await goToTab(tester, 'Metas');
    await tester.fling(
      find.text('Aún no tienes metas'),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('the auth sheet keeps Michi and the button above the keyboard', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    await pumpApp(tester, loggedIn: false);
    await scrollTo(tester, find.text('Crea tu cuenta'));
    await tester.tap(find.text('Crea tu cuenta'));
    await tester.pumpAndSettle();

    // It fits, so dragging doesn't move the form.
    final subtitle = find.text('Empieza a ordenar tus finanzas hoy.');
    final before = tester.getTopLeft(subtitle);
    await tester.drag(subtitle, const Offset(0, -150));
    await tester.pump();
    expect(tester.getTopLeft(subtitle), before);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextFormField, 'Contraseña'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.text('No miro, ¡lo prometo!').hitTestable(), findsOneWidget);
    expect(subtitle, findsNothing);
    final cta = find.text('Crear cuenta').hitTestable();
    expect(cta, findsOneWidget);
    expect(tester.getBottomLeft(cta).dy, lessThan(phone.height - 300));
  });

  for (final (scale, size) in [(1.0, const Size(320, 568)), (2.0, phone)]) {
    testWidgets('the welcome page scrolls when it does not fit '
        '($scale× at $size)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: size, loggedIn: false);
      await scrollTo(tester, find.text('Crea tu cuenta'));
      expect(find.text('Crea tu cuenta').hitTestable(), findsOneWidget);
    });
  }

  for (final size in [const Size(320, 740), phone, desktop]) {
    testWidgets('every tab renders without overflow at $size', (tester) async {
      await pumpApp(tester, size: size);
      for (final tab in ['Historial', 'Metas', 'Análisis']) {
        await goToTab(tester, tab);
      }
      await scrollTo(tester, find.text('Analizar con Michi'));
      await tester.tap(find.text('Analizar con Michi'));
      await tester.pumpAndSettle();
      expect(find.text('Michi analizó tus finanzas'), findsOneWidget);
      expect(find.textContaining('Tu mayor gasto es Comida'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await openProfile(tester);
      await scrollTo(tester, find.text('Cerrar sesión'));
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('empty account renders at $size', (tester) async {
      await pumpApp(tester, size: size, withData: false);
      await scrollTo(tester, find.text('Sin movimientos'));
      expect(find.text('Sin movimientos'), findsOneWidget);
      await goToTab(tester, 'Historial');
      expect(find.text('Tu historial empieza aquí'), findsOneWidget);
      await goToTab(tester, 'Metas');
      expect(find.text('Aún no tienes metas'), findsOneWidget);
      await goToTab(tester, 'Análisis');
      await scrollTo(tester, find.text('Sin gastos registrados'));
      expect(find.text('Sin gastos registrados'), findsOneWidget);
    });
  }

  for (final (scale, size) in [
    (1.6, phone),
    (2.0, phone),
    (2.0, const Size(320, 740)),
  ]) {
    testWidgets('large text ($scale×) renders without overflow at $size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: size);
      await scrollTo(tester, find.text('Metas de ahorro'));
      for (final tab in ['Historial', 'Metas', 'Análisis']) {
        await goToTab(tester, tab);
      }
      await scrollTo(tester, find.text('Analizar con Michi'));
      await openProfile(tester);
      await goToTab(tester, 'Inicio');
      await tester.tap(find.byTooltip('Personalizar inicio').first);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Widget del teléfono'));
      await goBack(tester);
      await tester.tap(find.byTooltip('Registrar movimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar gasto'), findsOneWidget);
    });
  }

  testWidgets('deletes a movement and can undo it', (tester) async {
    final backend = await pumpApp(tester);
    await goToTab(tester, 'Historial');

    await scrollTo(tester, find.text('Almuerzo facultad'));
    await tester.tap(find.text('Almuerzo facultad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('deleteTransaction:t2'));
    expect(find.text('"Almuerzo facultad" eliminado'), findsOneWidget);
    expect(find.text('Almuerzo facultad'), findsNothing);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    final restored = backend.transactions.last;
    expect(restored.title, 'Almuerzo facultad');
    expect(restored.amount, 8.5);
    expect(restored.date, DateTime(2026, 9, 22, 12));
    await scrollTo(tester, find.text('Almuerzo facultad'));
    expect(find.text('Almuerzo facultad'), findsOneWidget);
  });

  testWidgets('edits a movement', (tester) async {
    final backend = await pumpApp(tester);
    await goToTab(tester, 'Historial');

    await scrollTo(tester, find.text('Almuerzo facultad'));
    await tester.tap(find.text('Almuerzo facultad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar movimiento'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '12');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(backend.transactions.firstWhere((t) => t.id == 't2').amount, 12);
    expect(find.text('Movimiento actualizado'), findsOneWidget);
    expect(find.text(r'−$12.00'), findsOneWidget);
  });

  testWidgets('goal contributions cannot be edited as movements', (
    tester,
  ) async {
    await pumpApp(tester);
    await goToTab(tester, 'Historial');

    await scrollTo(tester, find.text('Ahorro: Laptop'));
    await tester.tap(find.text('Ahorro: Laptop'));
    await tester.pumpAndSettle();
    expect(find.text('Ir a Metas'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('registers a new expense from the FAB', (tester) async {
    final backend = await pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '4,5');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Café',
    );
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    final created = backend.transactions.last;
    expect(created.title, 'Café');
    expect(created.amount, 4.5);
    expect(created.category.id, food.id);
    expect(find.text('Gasto registrado'), findsOneWidget);
  });

  testWidgets('a scanned receipt prefills the expense to review', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final backend = await pumpApp(
      tester,
      scan: ScanDraft(
        source: ScanSource.invoice,
        reference: '9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C',
        date: yesterday,
        invoiceUrl: Uri.parse(
          'https://admin.factura.gob.sv/consultaPublica?codGen=9F3A',
        ),
        amount: 12.5,
        merchant: 'Pollo Campero',
      ),
    );
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escanear factura o ticket'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Leí el ticket'), findsOneWidget);
    expect(find.text('Ver factura en Hacienda'), findsOneWidget);
    expect(find.text('12.50'), findsOneWidget);
    expect(find.text('Pollo Campero'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    await scrollTo(tester, find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();

    final saved = backend.transactions.last;
    expect(saved.amount, 12.5);
    expect(saved.title, 'Pollo Campero');
    expect(saved.category.id, food.id, reason: 'suggested from the name');
    expect(saved.reference, '9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C');
    expect(saved.date.day, yesterday.day);

    // Scanning the same receipt again asks before saving it twice.
    final count = backend.transactions.length;
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escanear factura o ticket'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(find.text('¿Registrarlo de nuevo?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(backend.transactions, hasLength(count));
    expect(find.text('Guardar gasto'), findsOneWidget, reason: 'still editing');
  });

  testWidgets('an invoice QR without amount asks for it', (tester) async {
    await pumpApp(
      tester,
      scan: ScanDraft(
        source: ScanSource.invoice,
        reference: 'ABC',
        date: DateTime.now(),
      ),
    );
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escanear factura o ticket'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escribe el monto'), findsOneWidget);
    await scrollTo(tester, find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    // Still on the form: the amount is required.
    expect(find.text('Ingresa un monto mayor a 0'), findsOneWidget);
  });

  testWidgets('keeps cards in the wallet and tags expenses with them', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await openProfile(tester);
    await scrollTo(tester, find.text('Mi wallet'));
    await tester.tap(find.text('Mi wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Tu wallet está vacía'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar método de pago'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Visa Agrícola',
    );
    final digits = find.widgetWithText(
      TextFormField,
      'Últimos 4 dígitos (opcional)',
    );
    // A whole card number can't be typed: only four digits fit.
    await tester.enterText(digits, '4111111111111111');
    expect(
      tester.widget<TextFormField>(digits).controller!.text,
      hasLength(lessThanOrEqualTo(4)),
    );
    await tester.enterText(digits, '4821');
    await scrollTo(tester, find.widgetWithText(TextFormField, 'Día de corte'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Límite de crédito (opcional)'),
      '500',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Día de corte'),
      '15',
    );
    await scrollTo(tester, find.text('Agregar a mi wallet'));
    await tester.tap(find.text('Agregar a mi wallet'));
    await tester.pumpAndSettle();

    final card = backend.paymentMethods.single;
    expect(card.kind, PaymentMethodKind.creditCard);
    expect(card.last4, '4821');
    expect(card.statementDay, 15);
    expect(find.text('•••• 4821'), findsOneWidget);

    // A new expense starts with the card already in the wallet once used.
    await goBack(tester);
    await goToTab(tester, 'Inicio');
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '20');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Super',
    );
    await scrollTo(tester, find.text('Visa Agrícola ··4821'));
    await tester.tap(find.text('Visa Agrícola ··4821'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.transactions.last.paymentMethodId, card.id);

    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Visa Agrícola ··4821'));
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Visa Agrícola ··4821'),
    );
    expect(chip.selected, isTrue, reason: 'last used method preselected');
    Navigator.pop(tester.element(find.text('Pagado con')));
    await tester.pumpAndSettle();

    // The wallet adds it to this statement and the card can be removed.
    await openProfile(tester);
    await scrollTo(tester, find.text('Mi wallet'));
    await tester.tap(find.text('Mi wallet'));
    await tester.pumpAndSettle();
    expect(find.text(r'$20.00'), findsOneWidget);
    expect(find.textContaining(r'Disponible $480.00'), findsOneWidget);

    await tester.tap(find.text('•••• 4821'));
    await tester.pumpAndSettle();
    expect(find.text('Gastado en este corte'), findsOneWidget);
    await scrollTo(tester, find.text('Editar'));
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Quitar de la wallet'));
    await tester.tap(find.text('Quitar de la wallet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('queda en tu historial'), findsOneWidget);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(backend.paymentMethods, isEmpty);
    expect(backend.transactions.last.paymentMethodId, isNull);
  });

  testWidgets('adds funds to a goal and blocks amounts above the balance', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await goToTab(tester, 'Metas');

    await tester.tap(find.text('Aportar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Aportar').last);
    await tester.pumpAndSettle();
    expect(find.text('Supera tu balance disponible'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Aportar').last);
    await tester.pumpAndSettle();
    expect(backend.goals.single.savedAmount, 70);
    expect(find.text(r'Ahorrado $70.00'), findsOneWidget);
  });

  testWidgets('deleting a goal returns its money to the balance', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await goToTab(tester, 'Metas');

    await tester.tap(find.byTooltip('Opciones de la meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'$50.00 ahorrados volverán'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(backend.calls, contains('deleteGoal:g1'));
    expect(backend.balance, 191.5);
    expect(find.text('Aún no tienes metas'), findsOneWidget);
  });

  testWidgets('edits the profile name and logs out', (tester) async {
    final backend = await pumpApp(tester);
    await openProfile(tester);

    await tester.tap(find.byTooltip('Editar nombre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Dani');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Dani'), findsOneWidget);

    await scrollTo(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('logout'));
    expect(find.text('Comenzar'), findsOneWidget);
  });

  testWidgets('creates, edits and deletes a category', (tester) async {
    final backend = await pumpApp(tester);
    await openProfile(tester);
    await scrollTo(tester, find.text('Categorías'));
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes categorías propias'), findsOneWidget);
    // System categories are listed with their movement count, read-only.
    expect(find.text('Comida'), findsOneWidget);

    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Gimnasio');
    await tester.tap(find.text('Crear categoría').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('createCategory:Gimnasio'));
    expect(find.text('Gimnasio'), findsOneWidget);

    // A repeated name is refused inline.
    await tester.tap(find.byTooltip('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'comida');
    await tester.tap(find.text('Crear categoría').last);
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una categoría "comida"'), findsOneWidget);
    Navigator.of(tester.element(find.byType(CategorySheet))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gimnasio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Deporte');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Deporte'), findsOneWidget);

    await tester.tap(find.text('Deporte'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Eliminar categoría'));
    await tester.tap(find.text('Eliminar categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('deleteCategory:cat-1'));
    expect(find.text('Deporte'), findsNothing);
    expect(find.text('Aún no tienes categorías propias'), findsOneWidget);
  });

  testWidgets('a new category can be created from the movement form', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Nueva'));
    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Mascotas');
    await tester.tap(find.text('Crear categoría').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('createCategory:Mascotas'));
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Mascotas'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('sets, edits and removes a monthly budget', (tester) async {
    final backend = await pumpApp(tester);
    // Spending this month in Comida: over the limit set below.
    backend.transactions.add(
      Transaction(
        id: 't-now',
        title: 'Supermercado',
        amount: 30,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
      ),
    );
    await goToTab(tester, 'Análisis');
    await scrollTo(tester, find.text('Ponle un límite a tus gastos'));
    await tester.tap(find.text('Ponle un límite a tus gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.enterText(find.byType(TextFormField), '20');
    await tester.tap(find.text('Crear presupuesto'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('setBudget:cat-food:20.0'));
    await scrollTo(tester, find.textContaining(r'Te pasaste por $10.00'));
    expect(find.text('150%'), findsOneWidget);

    await scrollTo(tester, find.text('150%'));
    await tester.tap(find.text('150%'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '60');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);

    await scrollTo(tester, find.text('50%'));
    await tester.tap(find.text('50%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar presupuesto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar').last);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('deleteBudget:cat-food'));
    expect(find.text('Ponle un límite a tus gastos'), findsOneWidget);
  });

  testWidgets('remembers a hidden balance', (tester) async {
    await pumpApp(tester);
    expect(find.text(r'$141.50'), findsOneWidget);
    await tester.tap(find.byTooltip('Ocultar balance'));
    await tester.pumpAndSettle();
    expect(find.text(r'$141.50'), findsNothing);
    await goToTab(tester, 'Metas');
    await goToTab(tester, 'Inicio');
    expect(find.text('••••••'), findsOneWidget);
  });

  testWidgets('payment reminders are scheduled once turned on', (tester) async {
    final reminders = FakePaymentReminderService(allow: false);
    final backend = await pumpApp(tester, reminders: reminders);
    backend.paymentMethods.add(
      PaymentMethod(
        id: 'visa',
        name: 'Visa',
        kind: PaymentMethodKind.creditCard,
        color: 'ink',
        last4: '4821',
        dueDay: DateTime.now().day == 28 ? 27 : 28,
      ),
    );
    backend.transactions.add(
      Transaction(
        id: 'buy',
        title: 'Zapatos',
        amount: 60,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
        paymentMethodId: 'visa',
      ),
    );
    await openProfile(tester);
    await scrollTo(tester, find.text('Recordatorios de pago'));
    Finder reminderSwitch() => find.descendant(
      of: find.widgetWithText(InsetTile, 'Recordatorios de pago'),
      matching: find.byType(CupertinoSwitch),
    );

    // Permission denied: stays off and says where to enable it.
    await tester.tap(reminderSwitch());
    await tester.pumpAndSettle();
    expect(reminders.permissionRequests, 1);
    expect(tester.widget<CupertinoSwitch>(reminderSwitch()).value, isFalse);
    expect(find.textContaining('ajustes del teléfono'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);

    reminders.allow = true;
    await tester.tap(reminderSwitch());
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(reminderSwitch()).value, isTrue);
    expect(reminders.scheduled, isNotEmpty);
    expect(reminders.scheduled.last.title, 'Hoy vence tu Visa ··4821');

    await tester.tap(reminderSwitch());
    await tester.pumpAndSettle();
    expect(reminders.scheduled, isEmpty, reason: 'turned off');
  });

  testWidgets('shows when the data on screen is saved, not live', (
    tester,
  ) async {
    await pumpApp(tester);
    final api = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(apiClientProvider);
    expect(
      find.text('Sin conexión · lo último guardado').hitTestable(),
      findsNothing,
    );

    api.offline.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión · lo último guardado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    api.offline.value = false;
    await tester.pumpAndSettle();
    expect(
      find.text('Sin conexión · lo último guardado').hitTestable(),
      findsNothing,
    );
  });

  testWidgets('adds a subscription from the catalog and pauses it', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await openProfile(tester);
    await scrollTo(tester, find.text('Suscripciones'));
    await tester.tap(find.text('Suscripciones'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes suscripciones'), findsOneWidget);

    await tester.tap(find.byTooltip('Spotify'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio'),
      '5.99',
    );
    await scrollTo(tester, find.text('Agregar suscripción').last);
    await tester.tap(find.text('Agregar suscripción').last);
    await tester.pumpAndSettle();

    final rule = backend.recurring.single;
    expect(rule.service, 'spotify');
    expect(rule.title, 'Spotify');
    expect(rule.category.name, 'Suscripciones', reason: 'created for it');
    expect(
      rule.nextDate.isAfter(DateTime.now()),
      isTrue,
      reason: 'no charge today',
    );
    expect(find.text(r'$5.99'), findsWidgets);
    expect(find.text(r'$71.88 al año · 1 activa'), findsOneWidget);

    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Activa'));
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InsetTile, 'Activa'),
        matching: find.byType(CupertinoSwitch),
      ),
    );
    await scrollTo(tester, find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(backend.recurring.single.active, isFalse);
    expect(find.text('En pausa'), findsWidgets);
  });

  testWidgets('the cards widget on Inicio shows what is owed', (tester) async {
    final backend = await pumpApp(tester);
    backend.paymentMethods.add(
      const PaymentMethod(
        id: 'visa',
        name: 'Visa',
        kind: PaymentMethodKind.creditCard,
        color: 'ink',
        last4: '4821',
      ),
    );
    backend.transactions.add(
      Transaction(
        id: 'buy',
        title: 'Zapatos',
        amount: 60,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
        paymentMethodId: 'visa',
      ),
    );
    await tester.tap(find.byTooltip('Personalizar inicio'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byTooltip('Añadir Tarjetas'));
    // Centered: at the top edge the collapsed title bar would cover it.
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Añadir Tarjetas')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir Tarjetas'));
    await tester.pumpAndSettle();
    await goBack(tester);

    await scrollTo(tester, find.text('Mis tarjetas'));
    expect(find.text('Visa ··4821'), findsOneWidget);
    expect(find.text(r'Debes $60.00'), findsOneWidget);
    await tester.tap(find.text('Mis tarjetas'));
    await tester.pumpAndSettle();
    expect(find.text('Mi wallet'), findsOneWidget);
  });

  testWidgets('customizes the widgets on Inicio', (tester) async {
    await pumpApp(tester);
    final prefs = await SharedPreferences.getInstance();
    await tester.tap(find.byTooltip('Personalizar inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Tu inicio'), findsOneWidget);

    // Add the week chart from the gallery; it shows on Inicio.
    await scrollTo(tester, find.byTooltip('Añadir Esta semana'));
    await tester.tap(find.byTooltip('Añadir Esta semana'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Añadir Esta semana'), findsNothing);
    await goBack(tester);
    await scrollTo(tester, find.text('Gastado en 7 días'));

    // A long press edits it: wide and black.
    await tester.longPress(find.text('Gastado en 7 días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grande'));
    await tester.tap(find.byTooltip('Negro'));
    await tester.pumpAndSettle();
    expect(
      prefs.getString('home_layout_u1'),
      contains('{"type":"week","size":"wide","style":"ink"}'),
    );
    expect(find.text('Hoy'), findsWidgets);
    await tester.tap(find.text('Quitar del inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Gastado en 7 días'), findsNothing);

    // Removing every widget leaves an empty Inicio; reset brings them back.
    // (Also reachable from the button at the end of Inicio.)
    await scrollTo(tester, find.text('Personalizar inicio'));
    await tester.tap(find.text('Personalizar inicio'));
    await tester.pumpAndSettle();
    while (find.byTooltip(RegExp('^Quitar ')).evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip(RegExp('^Quitar ')).first);
      await tester.pumpAndSettle();
    }
    await goBack(tester);
    expect(find.text('Tu inicio está vacío'), findsOneWidget);
    await tester.tap(find.text('Añadir widgets'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restablecer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restablecer').last);
    await tester.pumpAndSettle();
    await goBack(tester);
    expect(find.text('Balance disponible'), findsOneWidget);
  });

  testWidgets('the phone widget follows its settings and the balance', (
    tester,
  ) async {
    final phoneWidget = FakePhoneWidgetService();
    await pumpApp(tester, phoneWidget: phoneWidget);
    expect(phoneWidget.payloads.last.amount, r'$141.50');
    expect(phoneWidget.payloads.last.theme.name, 'dark');

    // Hiding the balance on Inicio hides it on the phone too.
    await tester.tap(find.byTooltip('Ocultar balance'));
    await tester.pumpAndSettle();
    expect(phoneWidget.payloads.last.amount, '••••••');

    await tester.tap(find.byTooltip('Personalizar inicio'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Widget del teléfono'));
    await scrollTo(tester, find.byTooltip('Lima'));
    await tester.tap(find.text('Meta'));
    await tester.tap(find.byTooltip('Lima'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PhoneWidgetPreview),
        matching: find.text('Laptop'),
      ),
      findsOneWidget,
    );
    final payload = phoneWidget.payloads.last;
    expect(
      (payload.title, payload.amount, payload.theme.name),
      ('Laptop', '6%', 'lime'),
    );
  });

  testWidgets('withdraws money from a goal back to the balance', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    await goToTab(tester, 'Metas');
    await tester.tap(find.byTooltip('Opciones de la meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar dinero'));
    await tester.pumpAndSettle();
    expect(find.text('Retirar de Laptop'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '80');
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();
    expect(find.text('Supera lo ahorrado en la meta'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('withdraw:g1:20.0'));
    expect(backend.goals.single.savedAmount, 30);
    expect(find.text(r'$20.00 volvieron a tu balance'), findsOneWidget);

    // The withdrawal shows in Historial as money coming back.
    await goToTab(tester, 'Historial');
    await scrollTo(tester, find.text('Retiro: Laptop'));
    expect(find.text(r'+$20.00'), findsOneWidget);
  });

  testWidgets('a monthly movement creates a recurring rule', (tester) async {
    final backend = await pumpApp(tester);
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '12');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Spotify',
    );
    await scrollTo(tester, find.text('Cada mes'));
    await tester.tap(find.text('Cada mes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('createRecurring:Spotify:monthly'));
    expect(find.text('Se repetirá cada mes'), findsOneWidget);
    expect(backend.transactions.last.isRecurring, isTrue);

    // Listed in Perfil > Movimientos recurrentes; it can be paused.
    await openProfile(tester);
    await scrollTo(tester, find.text('Movimientos recurrentes'));
    await tester.tap(find.text('Movimientos recurrentes'));
    await tester.pumpAndSettle();
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.textContaining('Mensual · próximo'), findsOneWidget);
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(backend.recurring.single.active, isFalse);
    expect(find.text('En pausa'), findsOneWidget);

    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar recurrente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(backend.recurring, isEmpty);
    expect(find.text('Nada se repite todavía'), findsOneWidget);
  });

  testWidgets('paying a credit card lowers the debt, not the balance', (
    tester,
  ) async {
    final backend = await pumpApp(tester);
    backend.paymentMethods.add(
      const PaymentMethod(
        id: 'visa',
        name: 'Visa',
        kind: PaymentMethodKind.creditCard,
        color: 'ink',
        last4: '4821',
        creditLimit: 500,
      ),
    );
    backend.transactions.add(
      Transaction(
        id: 'buy',
        title: 'Zapatos',
        amount: 200,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
        paymentMethodId: 'visa',
      ),
    );
    final balance = backend.balance;

    await openProfile(tester);
    await scrollTo(tester, find.text('Mi wallet'));
    await tester.tap(find.text('Mi wallet'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'Debes $200.00'), findsOneWidget);

    await tester.tap(find.text('•••• 4821'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Registrar pago'));
    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No cuenta como gasto'), findsOneWidget);
    expect(find.text(r'Deuda total · $200.00'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto pagado'),
      '150',
    );
    await scrollTo(tester, find.text('Registrar pago').last);
    await tester.tap(find.text('Registrar pago').last);
    await tester.pumpAndSettle();

    expect(backend.cardPayments.single.amount, 150);
    expect(backend.balance, balance, reason: 'not an expense');
    expect(find.text(r'Debes $50.00'), findsOneWidget);

    // A payment entered by mistake can be deleted: the debt comes back.
    await scrollTo(tester, find.byTooltip('Borrar pago'));
    await tester.tap(find.byTooltip('Borrar pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(backend.cardPayments, isEmpty);
    expect(find.text(r'Debes $200.00'), findsWidgets);
  });

  testWidgets('a recurring rule pays with a wallet method', (tester) async {
    final backend = await pumpApp(tester);
    backend.paymentMethods.add(
      const PaymentMethod(
        id: 'pm1',
        name: 'Débito',
        kind: PaymentMethodKind.debitCard,
        color: 'ocean',
        last4: '0937',
      ),
    );
    await tester.tap(find.byTooltip('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '9');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Netflix',
    );
    await scrollTo(tester, find.text('Débito ··0937'));
    await tester.tap(find.text('Débito ··0937'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Cada mes'));
    await tester.tap(find.text('Cada mes'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Guardar gasto'));
    await tester.tap(find.text('Guardar gasto'));
    await tester.pumpAndSettle();
    expect(backend.recurring.single.paymentMethodId, 'pm1');
    expect(backend.transactions.last.paymentMethodId, 'pm1');

    // Editing the rule can clear it.
    await openProfile(tester);
    await scrollTo(tester, find.text('Movimientos recurrentes'));
    await tester.tap(find.text('Movimientos recurrentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Netflix'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Débito ··0937'));
    await tester.tap(find.text('Débito ··0937'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(backend.recurring.single.paymentMethodId, isNull);
  });

  testWidgets('exports the movements as CSV', (tester) async {
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
    await pumpApp(tester);
    await goToTab(tester, 'Historial');
    await tester.tap(find.byTooltip('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(copied, contains('Almuerzo facultad'));
    expect(find.textContaining('copiados como CSV'), findsOneWidget);
  });

  testWidgets('the budget calculator works from the salary', (tester) async {
    final backend = await pumpApp(tester);
    backend.transactions.add(
      Transaction(
        id: 't-recent',
        title: 'Supermercado',
        amount: 42,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: food,
      ),
    );
    await goToTab(tester, 'Análisis');
    await scrollTo(tester, find.text('Calcular mis presupuestos'));
    await tester.tap(find.text('Calcular mis presupuestos'));
    await tester.pumpAndSettle();
    expect(find.text('Calculadora'), findsOneWidget);

    // Start from a clean list of incomes (history may prefill one).
    while (find.text('Trabajo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Trabajo').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar ingreso'));
      await tester.pumpAndSettle();
    }

    // A salary paid every two weeks: $200 × 2 = $400 a month.
    await tester.tap(find.textContaining('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Sueldo'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto que recibes'),
      '200',
    );
    await tester.tap(find.text('Quincenal'));
    await tester.pumpAndSettle();
    expect(find.text(r'Equivale a $400.00 al mes.'), findsOneWidget);
    await tester.tap(find.text('Guardar ingreso'));
    await tester.pumpAndSettle();
    expect(find.text(r'$400.00/mes'), findsOneWidget);

    // 50/30/20 of $400, then 70/20/10.
    expect(find.text(r'$200.00'), findsWidgets);
    expect(find.text(r'$80.00'), findsWidgets);
    await tester.tap(find.text('70/20/10'));
    await tester.pumpAndSettle();
    expect(find.text(r'$280.00'), findsOneWidget);

    // Type a limit for Comida instead of the suggestion.
    await scrollTo(tester, find.text('Comida'));
    final comidaRow = find.ancestor(
      of: find.text('Comida'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: comidaRow.first, matching: find.byType(TextButton)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Aplicar'));
    await tester.tap(find.textContaining('Aplicar'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('setBudget:cat-food:50.0'));
    expect(find.textContaining('aplicado'), findsOneWidget);
  });

  testWidgets('a budget can be a percent of the income', (tester) async {
    final backend = await pumpApp(tester);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      plannerIncomeKey,
      encodeIncomeSources(const [IncomeSource('Sueldo', 500)]),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).invalidate(monthlyIncomeProvider);

    await goToTab(tester, 'Análisis');
    await scrollTo(tester, find.text('Ponle un límite a tus gastos'));
    await tester.tap(find.text('Ponle un límite a tus gastos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Comida'));
    await tester.tap(find.text('% de mis ingresos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '15');
    await tester.pumpAndSettle();
    expect(find.textContaining(r'= $75.00 al mes'), findsOneWidget);
    await tester.tap(find.text('Crear presupuesto'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('setBudget:cat-food:75.0'));
  });
}
