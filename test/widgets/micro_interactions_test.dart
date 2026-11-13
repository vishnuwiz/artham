import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:artham/widgets/animated_charts.dart';
import 'package:artham/widgets/micro_interactions.dart';

void main() {
  sharedSlidingTests();

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

void sharedSlidingTests() {
  testWidgets('SlidingSegmented slides its pill to the tapped option', (
    tester,
  ) async {
    var selected = 0;
    Widget build() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SlidingSegmented(
            labels: const ['All', 'Income', 'Expenses'],
            selectedIndex: selected,
            onChanged: (index) => setState(() => selected = index),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build());
    final pill = find.byKey(const ValueKey('sliding-segmented-pill'));
    final before = tester.getTopLeft(pill).dx;

    await tester.tap(find.text('Expenses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final during = tester.getTopLeft(pill).dx;
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(pill).dx;

    expect(selected, 2);
    expect(during, greaterThan(before));
    expect(after, greaterThan(during));
  });

  testWidgets('AnimatedRing sweeps to the rounded percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AnimatedRing(value: 0.371))),
      ),
    );
    expect(find.text('0%'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('37%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showSavedCheck shows the overlay then closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSavedCheck(context),
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SuccessCheckOverlay), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SuccessCheckOverlay), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
