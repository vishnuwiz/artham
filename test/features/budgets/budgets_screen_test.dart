import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/budget_repository.dart';
import 'package:artham/features/budgets/budgets_screen.dart';

void main() {
  testWidgets('overall budget dialog saves the rollover setting', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set overall budget'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '1000');
    await tester.tap(find.text('Carry unused budget forward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final budget = await BudgetRepository(database).getMonthlyBudget(
      DateTime(now.year, now.month, 1),
    );

    expect(budget, isNotNull);
    expect(budget!.limitPaise, 100000);
    expect(budget.rolloverEnabled, isTrue);
  });
}
