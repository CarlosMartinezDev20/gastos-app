import 'package:appgastos/core/theme/app_accent.dart';
import 'package:appgastos/core/theme/app_palette.dart';
import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/core/utils/home_layout.dart';
import 'package:appgastos/core/utils/phone_widget.dart';
import 'package:appgastos/models/user_profile.dart';
import 'package:appgastos/providers/theme_provider.dart';
import 'package:appgastos/widgets/home_cards.dart';
import 'package:appgastos/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_flow_test.dart' as flow;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + .05) / (lo + .05);
}

/// What the app is painting with right now.
AppPalette _palette(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).extension()!;

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    Mascot.animate = false;
    WidgetController.hitTestWarningShouldBeFatal = true;
    await initializeDateFormatting('es');
  });

  group('accents', () {
    for (final accent in AppAccent.values) {
      test('${accent.label} keeps text readable', () {
        expect(_contrast(accent.onAccent, accent.accent), greaterThan(7));
        expect(_contrast(accent.onMintLight, accent.mintLight), greaterThan(7));
        expect(_contrast(accent.onMintDark, accent.mintDark), greaterThan(7));
        expect(_contrast(accent.widgetMuted, accent.accent), greaterThan(4.5));
        // On the dark cards (ink) the accent is the highlight.
        expect(
          _contrast(accent.accent, AppPalette.dark.card),
          greaterThan(4.5),
        );
      });
    }

    test('only tint the highlights: income stays green', () {
      for (final dark in [false, true]) {
        final base = dark ? AppPalette.dark : AppPalette.light;
        final violet = base.withAccent(AppAccent.violeta, dark: dark);
        expect(violet.accent, AppAccent.violeta.accent);
        expect(
          violet.mint,
          dark ? AppAccent.violeta.mintDark : AppAccent.violeta.mintLight,
        );
        expect(violet.positive, base.positive);
        expect(violet.chartIncome, base.chartIncome);
        expect(violet.card, base.card);
      }
      // Lima is today's palette, unchanged.
      final lima = AppPalette.light.withAccent(AppAccent.lima, dark: false);
      expect(lima.accent, AppPalette.light.accent);
      expect(lima.mint, AppPalette.light.mint);
      expect(lima.onMint, AppPalette.light.onMint);
    });

    test('map to and from the API, defaulting to Lima', () {
      for (final accent in AppAccent.values) {
        expect(AppAccent.fromApi(accent.apiValue), accent);
      }
      expect(AppAccent.fromApi(null), AppAccent.lima);
      expect(AppAccent.fromApi('PINK'), AppAccent.lima);
      expect(themeModeFromApi('SYSTEM'), ThemeMode.system);
      expect(themeModeFromApi(null), ThemeMode.light);
      expect(themeModeApiValue(ThemeMode.dark), 'DARK');
    });

    test('an API without themeMode falls back to darkMode', () {
      final old = UserProfile.fromJson({
        'id': 'u',
        'name': 'A',
        'email': 'a@b.c',
        'darkMode': true,
      });
      expect(old.themeMode, 'DARK');
      expect(old.accent, 'LIME');
    });
  });

  group('Inicio', () {
    test('income starts in lime and spending in ink', () {
      expect(defaultStyle(HomeWidgetType.income), HomeWidgetStyle.accent);
      expect(defaultStyle(HomeWidgetType.spending), HomeWidgetStyle.ink);
      expect(defaultStyle(HomeWidgetType.goals), HomeWidgetStyle.card);
    });

    testWidgets('the income tile keeps lime in another accent', (tester) async {
      late HomeTone income, other;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(accent: AppAccent.violeta),
          home: Builder(
            builder: (context) {
              income = HomeTone.of(
                context,
                HomeWidgetStyle.accent,
                type: HomeWidgetType.income,
              );
              other = HomeTone.of(
                context,
                HomeWidgetStyle.accent,
                type: HomeWidgetType.goals,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(income.background, AppAccent.lima.accent);
      expect(other.background, AppAccent.violeta.accent);
    });
  });

  group('phone widget', () {
    test('follows the accent and sends the resolved colors', () {
      const payload = PhoneWidgetPayload(
        theme: PhoneWidgetTheme.lime,
        accent: AppAccent.cielo,
        title: 't',
        amount: 'a',
        caption: 'c',
      );
      expect(payload.colors.background, AppAccent.cielo.accent.toARGB32());
      final data = payload.toData();
      expect(data['theme'], 'lime');
      expect(data['background'], '#FF7CC4FF');
      expect(
        data['foreground'],
        '#${AppAccent.cielo.onAccent.toARGB32().toRadixString(16).toUpperCase()}',
      );
      // Lila doesn't depend on the accent.
      expect(
        PhoneWidgetTheme.lilac.colors(AppAccent.ambar),
        PhoneWidgetTheme.lilac.colors(AppAccent.lima),
      );
    });
  });

  testWidgets(
    'Perfil → Apariencia changes the accent and the mode, and syncs them',
    (tester) async {
      final backend = await flow.pumpApp(tester);
      expect(_palette(tester).accent, AppAccent.lima.accent);

      await flow.openProfile(tester);
      await flow.scrollTo(tester, find.text('APARIENCIA'));
      await tester.tap(find.bySemanticsLabel('Color Violeta'));
      await tester.pumpAndSettle();
      expect(_palette(tester).accent, AppAccent.violeta.accent);
      expect(backend.user.accent, 'VIOLET');

      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(_brightness(tester), Brightness.dark);
      expect(backend.user.themeMode, 'DARK');
      expect(backend.user.darkMode, isTrue);
      // The accent survives the switch to dark.
      expect(_palette(tester).accent, AppAccent.violeta.accent);

      await tester.tap(find.text('Automático'));
      await tester.pumpAndSettle();
      expect(backend.user.themeMode, 'SYSTEM');
      // The test platform is light.
      expect(_brightness(tester), Brightness.light);
    },
  );

  testWidgets('signing in applies the appearance saved in the account', (
    tester,
  ) async {
    final backend = await flow.pumpApp(tester, loggedIn: false);
    backend.user = backend.user.copyWith(themeMode: 'DARK', accent: 'AMBER');
    await flow.scrollTo(tester, find.text('Comenzar'));
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      backend.user.email,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      backend.password,
    );
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
    expect(_palette(tester).accent, AppAccent.ambar.accent);
  });

  testWidgets('a device that only saved the old dark-mode switch stays dark', (
    tester,
  ) async {
    await flow.pumpApp(
      tester,
      loggedIn: false,
      prefs: {legacyDarkModeKey: true},
    );
    expect(_brightness(tester), Brightness.dark);
  });
}
