import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/budget_repository.dart';
import 'package:artham/features/insights/insights_screen.dart';

void main() {
  testWidgets('insights shows planned versus actual budget performance', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final accountId = await database.into(database.bankAccounts).insert(
      BankAccountsCompanion.insert(
        bankName: 'Test Bank',
        accountName: 'Primary',
        openingBalancePaise: 5000000,
        openingDate: month,
      ),
    );
    final foodCategoryId = await database.into(database.categories).insert(
      CategoriesCompanion.insert(name: 'Food', type: 'expense'),
    );

    final budgets = BudgetRepository(database);
    await budgets.saveMonthlyBudget(
      month: month,
      limitPaise: 10000000,
    );
    await budgets.saveCategoryBudget(
      month: month,
      categoryId: foodCategoryId,
      limitPaise: 6000000,
    );

    await database.into(database.moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        accountId: accountId,
        categoryId: Value(foodCategoryId),
        amountPaise: 2500000,
        transactionType: 'expense',
        transactionDate: DateTime(now.year, now.month, 10),
      ),
    );

    // Keep the full Insights content in the test viewport so assertions do
    // not depend on scrollable discovery or scroll timing.
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: InsightsScreen(database: database)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(
      find.text('Unable to load insights. Please try again.'),
      findsNothing,
    );
    expect(find.text('Budget performance'), findsOneWidget);
    expect(find.text('CATEGORIES ON TRACK'), findsOneWidget);
    expect(find.text('Planned vs actual'), findsOneWidget);
    expect(find.text('Category budget insights'), findsOneWidget);
    expect(find.text('Food'), findsWidgets);
  });
}
