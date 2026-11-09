import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/budget_repository.dart';

void main() {
  late AppDatabase database;
  late BudgetRepository repository;
  late int accountId;
  late int foodCategoryId;
  late int transportCategoryId;

  final april = DateTime(2027, 4, 1);
  final may = DateTime(2027, 5, 1);

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BudgetRepository(database);

    accountId = await database.into(database.bankAccounts).insert(
      BankAccountsCompanion.insert(
        bankName: 'Test Bank',
        accountName: 'Test Account',
        openingBalancePaise: 0,
        openingDate: DateTime(2027, 1, 1),
      ),
    );

    foodCategoryId = await database.into(database.categories).insert(
      CategoriesCompanion.insert(name: 'Food', type: 'expense'),
    );
    transportCategoryId = await database.into(database.categories).insert(
      CategoriesCompanion.insert(name: 'Transport', type: 'expense'),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> addExpense({
    required DateTime month,
    required int amountPaise,
    int? categoryId,
  }) async {
    await database.into(database.moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        accountId: accountId,
        categoryId: Value(categoryId),
        amountPaise: amountPaise,
        transactionType: 'expense',
        transactionDate: DateTime(month.year, month.month, 15),
      ),
    );
  }

  test('new budgets default rollover to off', () async {
    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 100000,
    );

    final budget = await repository.getMonthlyBudget(april);

    expect(budget, isNotNull);
    expect(budget!.rolloverEnabled, isFalse);
  });

  test('monthly budget carries positive unused amount forward', () async {
    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 100000,
      rolloverEnabled: true,
    );
    await addExpense(month: april, amountPaise: 70000);
    await repository.saveMonthlyBudget(
      month: may,
      limitPaise: 120000,
    );
    await addExpense(month: may, amountPaise: 20000);

    final result = await repository.getMonthlyBudgetRolloverAmounts(may);

    expect(result, isNotNull);
    expect(result!.baseBudgetPaise, 120000);
    expect(result.rolloverPaise, 30000);
    expect(result.availableBudgetPaise, 150000);
    expect(result.remainingPaise, 130000);
  });

  test('does not carry unused money when the prior budget opted out',
      () async {
    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 100000,
    );
    await addExpense(month: april, amountPaise: 25000);
    await repository.saveMonthlyBudget(
      month: may,
      limitPaise: 80000,
    );

    final result = await repository.getMonthlyBudgetRolloverAmounts(may);

    expect(result, isNotNull);
    expect(result!.rolloverPaise, 0);
    expect(result.availableBudgetPaise, 80000);
  });

  test('carries forward balances across consecutive enabled months', () async {
    final january = DateTime(2027, 1, 1);
    final february = DateTime(2027, 2, 1);
    final march = DateTime(2027, 3, 1);

    await repository.saveMonthlyBudget(
      month: january,
      limitPaise: 100000,
      rolloverEnabled: true,
    );
    await addExpense(month: january, amountPaise: 70000);
    await repository.saveMonthlyBudget(
      month: february,
      limitPaise: 50000,
      rolloverEnabled: true,
    );
    await addExpense(month: february, amountPaise: 40000);
    await repository.saveMonthlyBudget(
      month: march,
      limitPaise: 60000,
    );

    final result = await repository.getMonthlyBudgetRolloverAmounts(march);

    expect(result, isNotNull);
    expect(result!.rolloverPaise, 40000);
    expect(result.availableBudgetPaise, 100000);
  });

  test('monthly budget never carries a negative balance', () async {
    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 100000,
      rolloverEnabled: true,
    );
    await addExpense(month: april, amountPaise: 120000);
    await repository.saveMonthlyBudget(
      month: may,
      limitPaise: 80000,
    );

    final result = await repository.getMonthlyBudgetRolloverAmounts(may);

    expect(result, isNotNull);
    expect(result!.rolloverPaise, 0);
    expect(result.availableBudgetPaise, 80000);
  });

  test('rollover chain stops when a previous month has no budget', () async {
    await repository.saveMonthlyBudget(
      month: DateTime(2027, 1, 1),
      limitPaise: 100000,
      rolloverEnabled: true,
    );
    // February intentionally has no budget.
    await repository.saveMonthlyBudget(
      month: DateTime(2027, 3, 1),
      limitPaise: 50000,
    );

    final result = await repository.getMonthlyBudgetRolloverAmounts(
      DateTime(2027, 3, 1),
    );

    expect(result, isNotNull);
    expect(result!.rolloverPaise, 0);
    expect(result.availableBudgetPaise, 50000);
  });

  test('category rollover uses only that category expenses', () async {
    await repository.saveCategoryBudget(
      month: april,
      categoryId: foodCategoryId,
      limitPaise: 100000,
      rolloverEnabled: true,
    );
    await addExpense(
      month: april,
      amountPaise: 40000,
      categoryId: foodCategoryId,
    );
    await addExpense(
      month: april,
      amountPaise: 25000,
      categoryId: transportCategoryId,
    );
    await repository.saveCategoryBudget(
      month: may,
      categoryId: foodCategoryId,
      limitPaise: 60000,
    );

    final result = await repository.getCategoryBudgetRolloverAmounts(
      month: may,
      categoryId: foodCategoryId,
    );

    expect(result, isNotNull);
    expect(result!.rolloverPaise, 60000);
    expect(result.availableBudgetPaise, 120000);
  });

  test('editing a budget without a rollover option preserves its setting',
      () async {
    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 100000,
      rolloverEnabled: true,
    );

    await repository.saveMonthlyBudget(
      month: april,
      limitPaise: 125000,
    );

    final budget = await repository.getMonthlyBudget(april);

    expect(budget, isNotNull);
    expect(budget!.limitPaise, 125000);
    expect(budget.rolloverEnabled, isTrue);
  });

  test('monthly templates populate future months without overwriting edits',
      () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 150000,
      rolloverEnabled: true,
    );
    await repository.saveBudgetTemplate(
      categoryId: foodCategoryId,
      startMonth: april,
      limitPaise: 50000,
      rolloverEnabled: false,
    );

    // A manually edited May overall budget must not be replaced by a template.
    await repository.saveMonthlyBudget(
      month: may,
      limitPaise: 175000,
    );

    final applied = await repository.applyTemplatesForMonth(may);
    final overall = await repository.getMonthlyBudget(may);
    final food = await repository.getCategoryBudget(
      month: may,
      categoryId: foodCategoryId,
    );

    expect(applied, 3);
    expect(overall!.limitPaise, 175000);
    expect(food, isNotNull);
    expect(food!.limitPaise, 50000);
    expect(food.rolloverEnabled, isFalse);
  });

  test('repeated and concurrent template application is idempotent', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 90000,
      rolloverEnabled: false,
    );

    final results = await Future.wait([
      repository.applyTemplatesForMonth(may),
      repository.applyTemplatesForMonth(may),
    ]);

    expect(results.reduce((total, value) => total + value), 2);

    final budgets = await (database.select(database.budgets)
          ..where((budget) => budget.categoryId.isNull()))
        .get();
    expect(budgets, hasLength(2));

    expect(await repository.applyTemplatesForMonth(may), 0);
  });

  test('template does not populate months before its start month', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: may,
      limitPaise: 90000,
      rolloverEnabled: false,
    );

    expect(await repository.applyTemplatesForMonth(april), 0);
    expect(await repository.getMonthlyBudget(april), isNull);

    expect(await repository.applyTemplatesForMonth(may), 1);
    expect((await repository.getMonthlyBudget(may))!.limitPaise, 90000);
  });

  test('paused template stops creating budgets for later months', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 90000,
      rolloverEnabled: false,
    );

    await repository.applyTemplatesForMonth(april);
    await repository.setBudgetTemplateActive(
      categoryId: null,
      isActive: false,
    );

    final june = DateTime(2027, 6, 1);
    expect(await repository.applyTemplatesForMonth(june), 0);
    expect(await repository.getMonthlyBudget(june), isNull);

    // Previously created months remain unchanged.
    expect(await repository.getMonthlyBudget(april), isNotNull);
  });

  test('resuming a paused template restarts from the selected month', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 90000,
      rolloverEnabled: false,
    );
    await repository.setBudgetTemplateActive(
      categoryId: null,
      isActive: false,
    );
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: may,
      limitPaise: 110000,
      rolloverEnabled: true,
    );

    final template = await repository.getBudgetTemplate(categoryId: null);
    expect(template, isNotNull);
    expect(template!.startMonth, may);
    expect(template.limitPaise, 110000);
    expect(template.isActive, isTrue);

    expect(await repository.applyTemplatesForMonth(april), 0);
    expect(await repository.applyTemplatesForMonth(may), 1);
  });

  test('editing an active template starts the new plan in that month', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 100000,
      rolloverEnabled: false,
    );
    await repository.applyTemplatesForMonth(april);

    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: may,
      limitPaise: 150000,
      rolloverEnabled: true,
    );

    final june = DateTime(2027, 6, 1);
    final applied = await repository.applyTemplatesForMonth(june);
    final aprilBudget = await repository.getMonthlyBudget(april);
    final mayBudget = await repository.getMonthlyBudget(may);
    final juneBudget = await repository.getMonthlyBudget(june);

    expect(applied, 2);
    expect(aprilBudget!.limitPaise, 100000);
    expect(mayBudget!.limitPaise, 150000);
    expect(juneBudget!.limitPaise, 150000);
    expect(aprilBudget.rolloverEnabled, isFalse);
    expect(mayBudget.rolloverEnabled, isTrue);
  });

  test('budget summaries identify monthly templates', () async {
    await repository.saveBudgetTemplate(
      categoryId: null,
      startMonth: april,
      limitPaise: 100000,
      rolloverEnabled: false,
    );
    await repository.saveBudgetTemplate(
      categoryId: foodCategoryId,
      startMonth: april,
      limitPaise: 60000,
      rolloverEnabled: false,
    );
    await repository.applyTemplatesForMonth(april);
    await addExpense(
      month: april,
      amountPaise: 25000,
      categoryId: foodCategoryId,
    );

    final overall = await repository.getMonthlyBudgetSummary(april);
    final categories = await repository.getCategoryBudgetSummaries(april);
    final food = categories.firstWhere(
      (item) => item.category.id == foodCategoryId,
    );

    expect(overall!.repeatsMonthly, isTrue);
    expect(food.repeatsMonthly, isTrue);
    expect(food.availableBudgetPaise, 60000);
    expect(food.expensesPaise, 25000);
    expect(food.remainingPaise, 35000);
  });

}
