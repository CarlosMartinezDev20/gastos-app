import 'dart:ui';

import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/core/utils/onboarding_tour.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:appgastos/widgets/onboarding_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_flow_test.dart' as flow;

/// Lets Inicio's starter delay run out and the tour fade in.
Future<void> waitForTour(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// [finder], only inside the tour (the dock also says "Historial"…).
Finder inTour(Finder finder) =>
    find.descendant(of: find.byType(OnboardingTourOverlay), matching: finder);

/// Taps "Siguiente" until the last step, returning every title shown.
Future<List<String>> walkTour(WidgetTester tester) async {
  final titles = <String>[];
  while (true) {
    titles.add(
      onboardingSteps
          .firstWhere((s) => inTour(find.text(s.title)).evaluate().isNotEmpty)
          .title,
    );
    if (find.text('Siguiente').evaluate().isEmpty) return titles;
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    AppTheme.useGoogleFonts = false;
    Mascot.animate = false;
    await initializeDateFormatting('es');
  });

  test('leaves out the steps whose spot is not on screen', () {
    const steps = [
      TourStep(title: 'a', body: ''),
      TourStep(spot: TourSpot.balance, title: 'b', body: ''),
      TourStep(spot: TourSpot.add, title: 'c', body: ''),
      TourStep(title: 'd', body: ''),
    ];
    expect(tourStepsOnScreen(steps, (spot) => spot == TourSpot.add), [0, 2, 3]);
  });

  group('tourCardArea', () {
    const safe = Rect.fromLTRB(0, 40, 400, 800);

    test('goes below a spot near the top', () {
      final placement = tourCardArea(
        safe: safe,
        hole: const Rect.fromLTRB(20, 60, 380, 300),
      );
      expect(placement.below, isTrue);
      expect(placement.area.top, 316);
      expect(placement.area.bottom, 800);
    });

    test('goes above a spot near the bottom', () {
      final placement = tourCardArea(
        safe: safe,
        hole: const Rect.fromLTRB(150, 720, 250, 780),
      );
      expect(placement.below, isFalse);
      expect(placement.area.bottom, 704);
    });

    test('takes the whole screen without a spot or without room', () {
      expect(tourCardArea(safe: safe).area, safe);
      final tall = tourCardArea(
        safe: safe,
        hole: const Rect.fromLTRB(0, 100, 400, 740),
      );
      expect(tall.area, safe);
    });
  });

  test('only a new account gets the tour on its own', () {
    expect(shouldAutoStartTour(seen: false, hasMovements: false), isTrue);
    expect(shouldAutoStartTour(seen: true, hasMovements: false), isFalse);
    expect(shouldAutoStartTour(seen: false, hasMovements: true), isFalse);
  });

  testWidgets('a new account walks the tour and records a movement', (
    tester,
  ) async {
    await flow.pumpApp(tester, withData: false, tour: true);
    await waitForTour(tester);

    expect(find.text('¡Hola, soy Michi!'), findsOneWidget);
    expect(find.text('Paso 1 de ${onboardingSteps.length}'), findsOneWidget);
    final titles = await walkTour(tester);
    expect(titles, [for (final step in onboardingSteps) step.title]);

    // It goes back too.
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(inTour(find.text('Tu perfil')), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
    expect(find.text('¡Todo listo!'), findsNothing);
    expect(find.text('Guardar gasto'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(onboardingDoneKey('u1')), isTrue);
  });

  test('Michi looks at the spot, all the way once it is far', () {
    expect(tourGaze(Offset.zero, const Offset(0, -300)), const Offset(0, -1));
    expect(tourGaze(Offset.zero, const Offset(60, 0)), const Offset(.5, 0));
    expect(tourGaze(Offset.zero, Offset.zero), Offset.zero);
  });

  testWidgets('tapping Michi makes it talk; tapping the spot moves on', (
    tester,
  ) async {
    await flow.pumpApp(tester, withData: false, tour: true);
    await waitForTour(tester);

    await tester.tap(inTour(find.byType(Mascot)));
    await tester.pump();
    expect(inTour(find.text(tourQuips.first)), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(inTour(find.text(tourQuips.first)), findsNothing);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(inTour(find.text('Tu saldo')), findsOneWidget);
    // A tap outside the spot does nothing; on it, it's the next step.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(inTour(find.text('Tu saldo')), findsOneWidget);
    await tester.tapAt(TourTarget.rectOf(TourSpot.balance)!.center);
    await tester.pumpAndSettle();
    expect(inTour(find.text('Registra un movimiento')), findsOneWidget);
  });

  testWidgets('skipping it, it does not come back on its own', (tester) async {
    await flow.pumpApp(tester, withData: false, tour: true);
    await waitForTour(tester);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, soy Michi!'), findsNothing);

    await flow.goToTab(tester, 'Historial');
    await flow.goToTab(tester, 'Inicio');
    await waitForTour(tester);
    expect(find.text('¡Hola, soy Michi!'), findsNothing);
  });

  testWidgets('the system back closes it', (tester) async {
    await flow.pumpApp(tester, withData: false, tour: true);
    await waitForTour(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¡Hola, soy Michi!'), findsNothing);
    expect(find.text('Inicio'), findsWidgets);
  });

  testWidgets('an account with movements does not get it', (tester) async {
    await flow.pumpApp(tester, tour: true);
    await waitForTour(tester);
    expect(find.text('¡Hola, soy Michi!'), findsNothing);
  });

  testWidgets('Perfil replays it on Inicio', (tester) async {
    await flow.pumpApp(tester);
    await flow.openProfile(tester);
    await flow.scrollTo(tester, find.text('Ver recorrido de la app'));
    await tester.tap(find.text('Ver recorrido de la app'));
    await waitForTour(tester);
    expect(find.text('¡Hola, soy Michi!'), findsOneWidget);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Personalizar inicio'), findsOneWidget);
  });

  for (final (scale, size) in [
    (1.0, flow.desktop),
    (2.0, flow.phone),
    (2.0, const Size(320, 740)),
  ]) {
    testWidgets('every step fits with $scale× text at $size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await flow.pumpApp(tester, size: size, withData: false, tour: true);
      await waitForTour(tester);
      final titles = await walkTour(tester);
      expect(titles.last, '¡Todo listo!');
      await tester.tap(find.text('Más tarde'));
      await tester.pumpAndSettle();
    });
  }
}
