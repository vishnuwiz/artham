import 'package:drift/drift.dart';

import '../app_database.dart';

class BudgetRolloverAmounts {
  final int baseBudgetPaise;
  final int rolloverPaise;
  final int availableBudgetPaise;
  final int expensesPaise;
  final int remainingPaise;

  const BudgetRolloverAmounts({
    required this.baseBudgetPaise,
    required this.rolloverPaise,
    required this.availableBudgetPaise,
    required this.expensesPaise,
    required this.remainingPaise,
  });

  double get percentageUsed {
    if (availableBudgetPaise <= 0) return 0;
    return expensesPaise / availableBudgetPaise;
  }
}

class MonthlyBudgetSummary {
  final int budgetPaise;
  final int availableBudgetPaise;
  final int rolloverPaise;
  final bool rolloverEnabled;
  final int expensesPaise;
  final int remainingPaise;

  const MonthlyBudgetSummary({
    required this.budgetPaise,
    required this.availableBudgetPaise,
    required this.rolloverPaise,
    required this.rolloverEnabled,
    required this.expensesPaise,
    required this.remainingPaise,
  });

  double get percentageUsed {
    if (availableBudgetPaise <= 0) return 0;
    return expensesPaise / availableBudgetPaise;
  }
}

class CategoryBudgetSummary {
  final Category category;
  final int budgetPaise;
  final int availableBudgetPaise;
  final int rolloverPaise;
  final bool rolloverEnabled;
  final int expensesPaise;

  const CategoryBudgetSummary({
    required this.category,
    required this.budgetPaise,
    required this.expensesPaise,
    int? availableBudgetPaise,
    this.rolloverPaise = 0,
    this.rolloverEnabled = false,
  }) : availableBudgetPaise = availableBudgetPaise ?? budgetPaise;

  int get remainingPaise => availableBudgetPaise - expensesPaise;

  double get percentageUsed {
    if (availableBudgetPaise <= 0) return 0;
    return expensesPaise / availableBudgetPaise;
  }
}


class MonthlyBudgetHistoryItem {
  final DateTime month;
  final int? budgetPaise;
  final int expensesPaise;

  const MonthlyBudgetHistoryItem({
    required this.month,
    required this.budgetPaise,
    required this.expensesPaise,
  });

  bool get hasBudget => budgetPaise != null && budgetPaise! > 0;

  int get remainingPaise => (budgetPaise ?? 0) - expensesPaise;
}

class BudgetRepository {
  final AppDatabase database;

  BudgetRepository(this.database);

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _nextMonthStart(DateTime date) =>
      DateTime(date.year, date.month + 1, 1);

  Future<Budget?> getMonthlyBudget(DateTime month) async {
    final start = _monthStart(month);
    final budgets = await (database.select(database.budgets)
          ..where((budget) =>
              budget.monthStart.equals(start) & budget.categoryId.isNull())
          ..orderBy([(budget) => OrderingTerm.desc(budget.id)])
          ..limit(1))
        .get();
    return budgets.isEmpty ? null : budgets.first;
  }

  Future<void> saveMonthlyBudget({
    required DateTime month,
    required int limitPaise,
    bool? rolloverEnabled,
  }) async {
    if (limitPaise <= 0) {
      throw ArgumentError('Budget amount must be greater than zero.');
    }

    final start = _monthStart(month);
    final existing = await getMonthlyBudget(start);

    if (existing != null) {
      await (database.update(database.budgets)
            ..where((budget) => budget.id.equals(existing.id)))
          .write(BudgetsCompanion(
        monthStart: Value(start),
        limitPaise: Value(limitPaise),
        rolloverEnabled: rolloverEnabled == null
            ? const Value.absent()
            : Value(rolloverEnabled),
      ));
    } else {
      await database.into(database.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: const Value(null),
              monthStart: start,
              limitPaise: limitPaise,
              rolloverEnabled: Value(rolloverEnabled ?? false),
            ),
          );
    }
  }

  Future<Budget?> getCategoryBudget({
    required DateTime month,
    required int categoryId,
  }) async {
    final start = _monthStart(month);
    final budgets = await (database.select(database.budgets)
          ..where((budget) =>
              budget.monthStart.equals(start) &
              budget.categoryId.equals(categoryId))
          ..orderBy([(budget) => OrderingTerm.desc(budget.id)])
          ..limit(1))
        .get();
    return budgets.isEmpty ? null : budgets.first;
  }

  /// Removes the overall budget for the selected month.
  /// Transactions are not changed.
  Future<void> deleteMonthlyBudget(DateTime month) async {
    final start = _monthStart(month);
    await (database.delete(database.budgets)
          ..where((budget) =>
              budget.monthStart.equals(start) & budget.categoryId.isNull()))
        .go();
  }

  Future<void> saveCategoryBudget({
    required DateTime month,
    required int categoryId,
    required int limitPaise,
    bool? rolloverEnabled,
  }) async {
    if (limitPaise <= 0) {
      throw ArgumentError('Budget amount must be greater than zero.');
    }

    final start = _monthStart(month);
    final existing = await getCategoryBudget(
      month: start,
      categoryId: categoryId,
    );

    if (existing != null) {
      await (database.update(database.budgets)
            ..where((budget) => budget.id.equals(existing.id)))
          .write(BudgetsCompanion(
        monthStart: Value(start),
        limitPaise: Value(limitPaise),
        rolloverEnabled: rolloverEnabled == null
            ? const Value.absent()
            : Value(rolloverEnabled),
      ));
    } else {
      await database.into(database.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: Value(categoryId),
              monthStart: start,
              limitPaise: limitPaise,
              rolloverEnabled: Value(rolloverEnabled ?? false),
            ),
          );
    }
  }

  /// Removes a category budget for the selected month.
  /// The category and its transactions are not changed.
  Future<void> deleteCategoryBudget({
    required DateTime month,
    required int categoryId,
  }) async {
    final start = _monthStart(month);
    await (database.delete(database.budgets)
          ..where((budget) =>
              budget.monthStart.equals(start) &
              budget.categoryId.equals(categoryId)))
        .go();
  }

  Future<int> getMonthlyExpensesPaise(DateTime month) async {
    final start = _monthStart(month);
    final end = _nextMonthStart(month);
    final expenses = await (database.select(database.moneyTransactions)
          ..where((transaction) =>
              transaction.transactionType.equals('expense') &
              transaction.transactionDate.isBiggerOrEqualValue(start) &
              transaction.transactionDate.isSmallerThanValue(end)))
        .get();

    return expenses.fold<int>(
      0,
      (total, transaction) => total + transaction.amountPaise,
    );
  }

  Future<int> getCategoryExpensesPaise({
    required DateTime month,
    required int categoryId,
  }) async {
    final start = _monthStart(month);
    final end = _nextMonthStart(month);
    final expenses = await (database.select(database.moneyTransactions)
          ..where((transaction) =>
              transaction.transactionType.equals('expense') &
              transaction.categoryId.equals(categoryId) &
              transaction.transactionDate.isBiggerOrEqualValue(start) &
              transaction.transactionDate.isSmallerThanValue(end)))
        .get();

    return expenses.fold<int>(
      0,
      (total, transaction) => total + transaction.amountPaise,
    );
  }


  /// Returns the overall budget and actual expenses for the requested number
  /// of months, ending with [endingMonth] (or the current month).
  /// Months without a budget are included so spending history is not hidden.
  Future<List<MonthlyBudgetHistoryItem>> getMonthlyBudgetHistory({
    int months = 12,
    DateTime? endingMonth,
  }) async {
    if (months < 1) {
      throw ArgumentError.value(months, 'months', 'Must be at least 1.');
    }

    final end = _monthStart(endingMonth ?? DateTime.now());
    final start = DateTime(end.year, end.month - months + 1, 1);
    final history = <MonthlyBudgetHistoryItem>[];

    for (var index = 0; index < months; index++) {
      final month = DateTime(start.year, start.month + index, 1);
      final budget = await getMonthlyBudget(month);
      final expenses = await getMonthlyExpensesPaise(month);

      history.add(MonthlyBudgetHistoryItem(
        month: month,
        budgetPaise: budget?.limitPaise,
        expensesPaise: expenses,
      ));
    }

    return history;
  }


  /// Returns carry-forward amounts for the selected overall monthly budget.
  /// Rollover is applied month-by-month and stops at the first missing budget
  /// or a month where rollover is disabled. Only positive unused amounts carry.
  Future<BudgetRolloverAmounts?> getMonthlyBudgetRolloverAmounts(
    DateTime month,
  ) async {
    final current = await getMonthlyBudget(month);
    if (current == null) return null;

    final rollover = await _getRolloverFromPreviousMonths(
      month: month,
      categoryId: null,
    );
    final expenses = await getMonthlyExpensesPaise(month);
    final available = current.limitPaise + rollover;

    return BudgetRolloverAmounts(
      baseBudgetPaise: current.limitPaise,
      rolloverPaise: rollover,
      availableBudgetPaise: available,
      expensesPaise: expenses,
      remainingPaise: available - expenses,
    );
  }

  /// Returns carry-forward amounts for a selected category monthly budget.
  Future<BudgetRolloverAmounts?> getCategoryBudgetRolloverAmounts({
    required DateTime month,
    required int categoryId,
  }) async {
    final current = await getCategoryBudget(
      month: month,
      categoryId: categoryId,
    );
    if (current == null) return null;

    final rollover = await _getRolloverFromPreviousMonths(
      month: month,
      categoryId: categoryId,
    );
    final expenses = await getCategoryExpensesPaise(
      month: month,
      categoryId: categoryId,
    );
    final available = current.limitPaise + rollover;

    return BudgetRolloverAmounts(
      baseBudgetPaise: current.limitPaise,
      rolloverPaise: rollover,
      availableBudgetPaise: available,
      expensesPaise: expenses,
      remainingPaise: available - expenses,
    );
  }

  Future<int> _getRolloverFromPreviousMonths({
    required DateTime month,
    required int? categoryId,
  }) async {
    final eligibleBudgets = <Budget>[];
    var previousMonth = DateTime(month.year, month.month - 1, 1);

    // Walk backwards only while each month's budget explicitly allows its
    // unused amount to move forward. A missing/disabled month breaks the chain.
    while (true) {
      final budget = categoryId == null
          ? await getMonthlyBudget(previousMonth)
          : await getCategoryBudget(
              month: previousMonth,
              categoryId: categoryId,
            );

      if (budget == null || !budget.rolloverEnabled) {
        break;
      }

      eligibleBudgets.add(budget);
      previousMonth = DateTime(previousMonth.year, previousMonth.month - 1, 1);
    }

    // Apply the collected months from oldest to newest so each month's
    // available balance includes only carry-forward from its own predecessor.
    var carryForward = 0;
    for (final budget in eligibleBudgets.reversed) {
      final expenses = categoryId == null
          ? await getMonthlyExpensesPaise(budget.monthStart)
          : await getCategoryExpensesPaise(
              month: budget.monthStart,
              categoryId: categoryId,
            );
      final unused = budget.limitPaise + carryForward - expenses;
      carryForward = unused > 0 ? unused : 0;

      // Overspending consumes the entire amount; negative carry is not kept.
      if (carryForward == 0) break;
    }

    return carryForward;
  }

  Future<MonthlyBudgetSummary?> getMonthlyBudgetSummary(
    DateTime month,
  ) async {
    final amounts = await getMonthlyBudgetRolloverAmounts(month);
    if (amounts == null) return null;
    final budget = await getMonthlyBudget(month);
    if (budget == null) return null;

    return MonthlyBudgetSummary(
      budgetPaise: amounts.baseBudgetPaise,
      availableBudgetPaise: amounts.availableBudgetPaise,
      rolloverPaise: amounts.rolloverPaise,
      rolloverEnabled: budget.rolloverEnabled,
      expensesPaise: amounts.expensesPaise,
      remainingPaise: amounts.remainingPaise,
    );
  }

  Future<List<CategoryBudgetSummary>> getCategoryBudgetSummaries(
    DateTime month,
  ) async {
    final categories = await (database.select(database.categories)
          ..where((category) => category.type.equals('expense'))
          ..orderBy([(category) => OrderingTerm.asc(category.name)]))
        .get();

    final results = <CategoryBudgetSummary>[];
    for (final category in categories) {
      final amounts = await getCategoryBudgetRolloverAmounts(
        month: month,
        categoryId: category.id,
      );
      final budget = amounts == null
          ? null
          : await getCategoryBudget(
              month: month,
              categoryId: category.id,
            );
      final expenses = amounts?.expensesPaise ??
          await getCategoryExpensesPaise(
            month: month,
            categoryId: category.id,
          );

      results.add(CategoryBudgetSummary(
        category: category,
        budgetPaise: amounts?.baseBudgetPaise ?? 0,
        availableBudgetPaise: amounts?.availableBudgetPaise ?? 0,
        rolloverPaise: amounts?.rolloverPaise ?? 0,
        rolloverEnabled: budget?.rolloverEnabled ?? false,
        expensesPaise: expenses,
      ));
    }
    return results;
  }
}
