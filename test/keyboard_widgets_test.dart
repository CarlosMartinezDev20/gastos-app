import 'package:appgastos/widgets/ios_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts its builds.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(height: 40);
  }
}

/// Simulates the keyboard sliding up over a few frames.
Future<void> slideKeyboard(WidgetTester tester, List<double> insets) async {
  for (final inset in insets) {
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    await tester.pump();
  }
}

void main() {
  testWidgets('KeyboardInset follows the keyboard without rebuilding', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: KeyboardInset(extra: 10, child: _Probe(() => builds++)),
          ),
        ),
      ),
    );
    await slideKeyboard(tester, [50, 150, 300]);

    expect(builds, 1);
    final bottom = tester.getBottomLeft(find.byType(_Probe)).dy;
    expect(bottom, 800 - 300 - 10);
  });

  testWidgets('KeyboardVisibilityBuilder only rebuilds when it flips', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final seen = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: KeyboardVisibilityBuilder(
          builder: (context, visible) {
            seen.add(visible);
            return const SizedBox();
          },
        ),
      ),
    );
    await slideKeyboard(tester, [50, 150, 300, 150, 0]);

    expect(seen, [false, true, false]);
  });

  testWidgets('a covered page pauses and ignores the keyboard', (tester) async {
    addTearDown(tester.view.reset);
    var builds = 0;
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        home: PauseWhenCovered(
          child: Builder(
            builder: (context) {
              page = context;
              builds++;
              MediaQuery.viewInsetsOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(TickerMode.valuesOf(page).enabled, isTrue);

    showModalBottomSheet<void>(
      context: page,
      builder: (_) => const SizedBox(height: 100),
    );
    await tester.pumpAndSettle();
    final coveredBuilds = builds;
    expect(TickerMode.valuesOf(page).enabled, isFalse);

    await slideKeyboard(tester, [50, 150, 300]);
    expect(builds, coveredBuilds);
  });

  testWidgets('EntranceAutofocus waits for the sheet to finish opening', (
    tester,
  ) async {
    late BuildContext root;
    final field = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            root = context;
            return const SizedBox();
          },
        ),
      ),
    );
    showModalBottomSheet<void>(
      context: root,
      builder: (_) => EntranceAutofocus(
        builder: (context, focusNode) =>
            TextField(key: field, focusNode: focusNode),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    bool focused() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextField>()
            ?.key ==
        field;
    expect(focused(), isFalse);

    await tester.pumpAndSettle();
    expect(focused(), isTrue);
  });
}
