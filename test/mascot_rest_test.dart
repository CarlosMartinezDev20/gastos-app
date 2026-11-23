import 'dart:math' as math;

import 'package:appgastos/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps one idle loop (4 s) in frames, as the device would.
Future<void> idleLoop(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget kitten({MascotMood mood = MascotMood.happy, Offset? gaze}) =>
    MaterialApp(
      home: Center(
        child: Mascot(mood: mood, gaze: gaze, onTap: () {}),
      ),
    );

void main() {
  setUp(() {
    Mascot.animate = true;
    Mascot.random = math.Random(1);
  });
  tearDown(() => Mascot.animate = false);

  testWidgets('Michi rests after a few quiet loops and stops drawing', (
    tester,
  ) async {
    await tester.pumpWidget(kitten());
    for (var i = 0; i < Mascot.restAfterLoops; i++) {
      expect(tester.binding.hasScheduledFrame, isTrue);
      await idleLoop(tester);
    }
    // Let a spontaneous action or the pop-in finish, then nothing ticks.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a tap, a new mood or a gaze wake it up', (tester) async {
    await tester.pumpWidget(kitten());
    for (var i = 0; i <= Mascot.restAfterLoops; i++) {
      await idleLoop(tester);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.byType(Mascot));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);

    for (var i = 0; i <= Mascot.restAfterLoops; i++) {
      await idleLoop(tester);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(kitten(mood: MascotMood.calm));
    expect(tester.binding.hasScheduledFrame, isTrue);

    // While a form steers its eyes it stays awake.
    await tester.pumpWidget(kitten(mood: MascotMood.calm, gaze: Offset.zero));
    for (var i = 0; i <= Mascot.restAfterLoops + 1; i++) {
      await idleLoop(tester);
    }
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
