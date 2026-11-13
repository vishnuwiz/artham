import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:artham/widgets/animated_charts.dart';
import 'package:artham/widgets/micro_interactions.dart';

void main() {
  testWidgets('PressableScale shrinks while pressed and calls onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressableScale(
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(scale(), 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(scale(), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
  });

  testWidgets('skeleton placeholders build and animate', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(children: [SkeletonCards(count: 2), SkeletonAccountRow()]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SkeletonCards), findsOneWidget);
    expect(find.byType(SkeletonAccountRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AnimatedProgressBar pulse and shake finish without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: AnimatedProgressBar(value: 1, pulse: true, shake: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
