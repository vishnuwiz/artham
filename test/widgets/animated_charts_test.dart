import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:artham/widgets/animated_charts.dart';

void main() {
  testWidgets('AnimatedAmountText counts up to the final amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimatedAmountText(paise: 123456))),
    );
    expect(find.text('₹0.00'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('₹1234.56'), findsOneWidget);
  });

  testWidgets('AnimatedPercentText counts up to the final percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedPercentText(fraction: 0.425, suffix: ' used'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42.5% used'), findsOneWidget);
  });

  testWidgets('AnimatedProgressBar renders and settles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 200, child: AnimatedProgressBar(value: 0.5)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedProgressBar), findsOneWidget);
  });

  testWidgets('AnimatedDonutChart shows the total and a tapped slice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedDonutChart(
            centerLabel: 'Spent',
            formatValue: (value) => '₹${value.round()}',
            slices: const [
              DonutSlice(label: 'Food', value: 300, color: Colors.green),
              DonutSlice(label: 'Travel', value: 100, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SPENT'), findsOneWidget);
    expect(find.text('₹400'), findsOneWidget);

    // Selecting a legend row shows that slice's share in the centre.
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(find.text('TRAVEL'), findsOneWidget);
    expect(find.text('25.0%'), findsWidgets);
  });
}
