import 'package:drift/drift.dart';

import '../app_database.dart';

class MonthlyBudgetSummary {
  final int budgetPaise;
  final int expensesPaise;
  final int remainingPaise;

  const MonthlyBudgetSummary({
    required this.budgetPaise,
    required this.expensesPaise,
    required this.remainingPaise,
  });

  double get percentageUsed {
    if (budgetPaise <= 0) return 0;
    return expensesPaise / budgetPaise;
  }
}

class CategoryBudgetSummary {
  final Category category;
  final int budgetPaise;
  final int expensesPaise;

  const CategoryBudgetSummary({
    required this.category,
    required this.budgetPaise,
    required this.expensesPaise,
  });

  int get remainingPaise => budgetPaise - expensesPaise;

  double get percentageUsed {
    if (budgetPaise <= 0) return 0;
    return expensesPaise / budgetPaise;
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
      ));
    } else {
      await database.into(database.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: const Value(null),
              monthStart: start,
              limitPaise: limitPaise,
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
      ));
    } else {
      await database.into(database.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: Value(categoryId),
              monthStart: start,
              limitPaise: limitPaise,
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

  Future<MonthlyBudgetSummary?> getMonthlyBudgetSummary(
    DateTime month,
  ) async {
    final budget = await getMonthlyBudget(month);
    if (budget == null) return null;
    final expenses = await getMonthlyExpensesPaise(month);

    return MonthlyBudgetSummary(
      budgetPaise: budget.limitPaise,
      expensesPaise: expenses,
      remainingPaise: budget.limitPaise - expenses,
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
      final budget = await getCategoryBudget(
        month: month,
        categoryId: category.id,
      );
      final expenses = await getCategoryExpensesPaise(
        month: month,
        categoryId: category.id,
      );

      results.add(CategoryBudgetSummary(
        category: category,
        budgetPaise: budget?.limitPaise ?? 0,
        expensesPaise: expenses,
      ));
    }
    return results;
  }
}
