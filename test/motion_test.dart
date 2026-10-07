import 'package:appgastos/core/theme/app_theme.dart';
import 'package:appgastos/core/theme/motion.dart';
import 'package:appgastos/widgets/ios_ui.dart';
import 'package:appgastos/widgets/theme_crossfade.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app with a light/dark switch behind [ThemeCrossfade].
class _ThemedApp extends StatefulWidget {
  const _ThemedApp();

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  var _dark = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => ThemeCrossfade(child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () =>
              ThemeCrossfade.run(context, () => setState(() => _dark = !_dark)),
          child: const Text('Cambiar'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => AppTheme.useGoogleFonts = false);

  testWidgets('the theme switches at once under a fading snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(const _ThemedApp());
    await tester.tap(find.text('Cambiar'));
    await tester.pump();

    final scaffold = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(scaffold.color, ThemeData.dark().scaffoldBackgroundColor);
    expect(find.byType(RawImage), findsOneWidget);

    // Half way it is still fading out on top.
    await tester.pump(Motion.slow ~/ 2);
    expect(find.byType(RawImage), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('with reduced motion the theme switches without a fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const _ThemedApp());
    await tester.tap(find.text('Cambiar'));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
  });

  for (final reduced in [false, true]) {
    testWidgets('pushed pages ${reduced ? 'cross-fade' : 'slide'} '
        '(reduced motion: $reduced)', (tester) async {
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.light(),
          home: const Text('Inicio'),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Detalle')),
      );
      await tester.pump();
      await tester.pump(Motion.slow ~/ 2);

      final slides = find.ancestor(
        of: find.text('Detalle'),
        matching: find.byType(CupertinoPageTransition),
      );
      expect(slides, reduced ? findsNothing : findsOneWidget);
      // The page below moves aside with the slide. (With reduced motion
      // Flutter also runs the route's controller 20× faster, so by now it
      // has finished.)
      if (!reduced) {
        expect(tester.getTopLeft(find.text('Inicio')).dx, lessThan(0));
      }

      await tester.pump(Motion.slow);
      expect(tester.getTopLeft(find.text('Detalle')).dx, 0);
    });
  }

  testWidgets('a long staggered entrance stays short', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            for (var i = 0; i < 12; i++)
              FadeSlideIn(index: i, child: const SizedBox(height: 10)),
          ],
        ),
      ),
    );
    // The first frame starts the controllers; the last staggered item ends
    // after its delay plus one entrance.
    await tester.pump();
    // (Flutter ends an animation on the first frame past its duration.)
    await tester.pump(Motion.slow + Motion.stagger * Motion.maxStaggered);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
