import 'dart:async';

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
  final bool repeatsMonthly;
  final int expensesPaise;
  final int remainingPaise;

  const MonthlyBudgetSummary({
    required this.budgetPaise,
    required this.availableBudgetPaise,
    required this.rolloverPaise,
    required this.rolloverEnabled,
    required this.expensesPaise,
    required this.remainingPaise,
    this.repeatsMonthly = false,
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
  final bool repeatsMonthly;
  final int expensesPaise;

  const CategoryBudgetSummary({
    required this.category,
    required this.budgetPaise,
    required this.expensesPaise,
    int? availableBudgetPaise,
    this.rolloverPaise = 0,
    this.rolloverEnabled = false,
    this.repeatsMonthly = false,
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
  final int availableBudgetPaise;
  final int rolloverPaise;
  final bool rolloverEnabled;
  final int expensesPaise;

  const MonthlyBudgetHistoryItem({
    required this.month,
    required this.budgetPaise,
    required this.expensesPaise,
    int? availableBudgetPaise,
    this.rolloverPaise = 0,
    this.rolloverEnabled = false,
  }) : availableBudgetPaise =
           availableBudgetPaise ?? (budgetPaise ?? 0) + rolloverPaise;

  bool get hasBudget => budgetPaise != null && budgetPaise! > 0;

  int get remainingPaise => availableBudgetPaise - expensesPaise;
}

class BudgetRepository {
  static final Expando<Future<void>> _templateApplyTails =
      Expando<Future<void>>('budgetTemplateApplyTails');

  final AppDatabase database;

  BudgetRepository(this.database);

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _nextMonthStart(DateTime date) =>
      DateTime(date.year, date.month + 1, 1);

  /// Returns the recurring template for the overall budget (null category)
  /// or a specific category.
  Future<BudgetTemplate?> getBudgetTemplate({required int? categoryId}) async {
    final query = database.select(database.budgetTemplates)
      ..where(
        (template) => categoryId == null
            ? template.categoryId.isNull()
            : template.categoryId.equals(categoryId),
      )
      ..orderBy([(template) => OrderingTerm.desc(template.id)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<List<BudgetTemplate>> getBudgetTemplates({bool activeOnly = false}) {
    final query = database.select(database.budgetTemplates)
      ..orderBy([
        (template) => OrderingTerm.asc(template.categoryId),
        (template) => OrderingTerm.asc(template.id),
      ]);
    if (activeOnly) {
      query.where((template) => template.isActive.equals(true));
    }
    return query.get();
  }

  /// Creates or updates the monthly template for one overall/category budget.
  /// Editing a template establishes a new effective month for future copies.
  Future<void> saveBudgetTemplate({
    required int? categoryId,
    required DateTime startMonth,
    required int limitPaise,
    required bool rolloverEnabled,
    bool isActive = true,
  }) async {
    if (limitPaise <= 0) {
      throw ArgumentError('Budget template amount must be greater than zero.');
    }
    final existing = await getBudgetTemplate(categoryId: categoryId);
    // A template edit changes the plan from the selected month forward;
    // budgets already created for earlier months remain historical snapshots.
    final normalizedStart = _monthStart(startMonth);

    if (existing == null) {
      await database
          .into(database.budgetTemplates)
          .insert(
            BudgetTemplatesCompanion.insert(
              categoryId: Value(categoryId),
              startMonth: normalizedStart,
              limitPaise: limitPaise,
              rolloverEnabled: Value(rolloverEnabled),
              isActive: Value(isActive),
            ),
          );
    } else {
      await (database.update(
        database.budgetTemplates,
      )..where((template) => template.id.equals(existing.id))).write(
        BudgetTemplatesCompanion(
          startMonth: Value(normalizedStart),
          limitPaise: Value(limitPaise),
          rolloverEnabled: Value(rolloverEnabled),
          isActive: Value(isActive),
        ),
      );
    }
  }

  /// Pauses an existing template. Budgets already generated for earlier
  /// months are preserved; no new months will be populated while paused.
  Future<void> setBudgetTemplateActive({
    required int? categoryId,
    required bool isActive,
    int? limitPaise,
    bool? rolloverEnabled,
  }) async {
    final existing = await getBudgetTemplate(categoryId: categoryId);
    if (existing == null) return;

    await (database.update(
      database.budgetTemplates,
    )..where((template) => template.id.equals(existing.id))).write(
      BudgetTemplatesCompanion(
        isActive: Value(isActive),
        limitPaise: limitPaise == null
            ? const Value.absent()
            : Value(limitPaise),
        rolloverEnabled: rolloverEnabled == null
            ? const Value.absent()
            : Value(rolloverEnabled),
      ),
    );
  }

  /// Applies active templates to [month], but never overwrites a budget the
  /// user has already created or edited for that month.
  ///
  /// This is intentionally run when the app opens a budget view rather than
  /// through a background task. It creates budget limits only, not transactions.
  Future<int> applyTemplatesForMonth(DateTime month) async {
    // The Home, Budgets, and Insights views can request template application
    // close together. Serialize these operations per database so two screens
    // cannot both observe a missing month and insert duplicate budget rows.
    final previous = _templateApplyTails[database] ?? Future<void>.value();
    final gate = Completer<void>();
    _templateApplyTails[database] = gate.future;

    await previous;
    try {
      return await _applyTemplatesForMonth(month);
    } finally {
      gate.complete();
    }
  }

  Future<int> _applyTemplatesForMonth(DateTime month) async {
    final targetMonth = _monthStart(month);
    final templates =
        await (database.select(database.budgetTemplates)
              ..where(
                (template) =>
                    template.isActive.equals(true) &
                    template.startMonth.isSmallerOrEqualValue(targetMonth),
              )
              ..orderBy([(template) => OrderingTerm.asc(template.id)]))
            .get();

    var applied = 0;
    await database.transaction(() async {
      for (final template in templates) {
        // Backfill any months missed while the app was not opened. This keeps
        // the recurring plan consistent and makes the budget history complete.
        var monthToApply = _monthStart(template.startMonth);
        while (!monthToApply.isAfter(targetMonth)) {
          if (template.categoryId == null) {
            final existing = await getMonthlyBudget(monthToApply);
            if (existing == null) {
              await database
                  .into(database.budgets)
                  .insert(
                    BudgetsCompanion.insert(
                      categoryId: const Value(null),
                      monthStart: monthToApply,
                      limitPaise: template.limitPaise,
                      rolloverEnabled: Value(template.rolloverEnabled),
                    ),
                  );
              applied++;
            }
          } else {
            final category =
                await (database.select(database.categories)
                      ..where((item) => item.id.equals(template.categoryId!)))
                    .getSingleOrNull();
            if (category != null && category.type == 'expense') {
              final existing = await getCategoryBudget(
                month: monthToApply,
                categoryId: template.categoryId!,
              );
              if (existing == null) {
                await database
                    .into(database.budgets)
                    .insert(
                      BudgetsCompanion.insert(
                        categoryId: Value(template.categoryId),
                        monthStart: monthToApply,
                        limitPaise: template.limitPaise,
                        rolloverEnabled: Value(template.rolloverEnabled),
                      ),
                    );
                applied++;
              }
            }
          }

          monthToApply = _nextMonthStart(monthToApply);
        }
      }
    });
    return applied;
  }

  Future<Budget?> getMonthlyBudget(DateTime month) async {
    final start = _monthStart(month);
    final budgets =
        await (database.select(database.budgets)
              ..where(
                (budget) =>
                    budget.monthStart.equals(start) &
                    budget.categoryId.isNull(),
              )
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
      await (database.update(
        database.budgets,
      )..where((budget) => budget.id.equals(existing.id))).write(
        BudgetsCompanion(
          monthStart: Value(start),
          limitPaise: Value(limitPaise),
          rolloverEnabled: rolloverEnabled == null
              ? const Value.absent()
              : Value(rolloverEnabled),
        ),
      );
    } else {
      await database
          .into(database.budgets)
          .insert(
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
    final budgets =
        await (database.select(database.budgets)
              ..where(
                (budget) =>
                    budget.monthStart.equals(start) &
                    budget.categoryId.equals(categoryId),
              )
              ..orderBy([(budget) => OrderingTerm.desc(budget.id)])
              ..limit(1))
            .get();
    return budgets.isEmpty ? null : budgets.first;
  }

  /// Removes the overall budget for the selected month.
  /// Transactions are not changed.
  Future<void> deleteMonthlyBudget(DateTime month) async {
    final start = _monthStart(month);
    await (database.delete(database.budgets)..where(
          (budget) =>
              budget.monthStart.equals(start) & budget.categoryId.isNull(),
        ))
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
      await (database.update(
        database.budgets,
      )..where((budget) => budget.id.equals(existing.id))).write(
        BudgetsCompanion(
          monthStart: Value(start),
          limitPaise: Value(limitPaise),
          rolloverEnabled: rolloverEnabled == null
              ? const Value.absent()
              : Value(rolloverEnabled),
        ),
      );
    } else {
      await database
          .into(database.budgets)
          .insert(
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
    await (database.delete(database.budgets)..where(
          (budget) =>
              budget.monthStart.equals(start) &
              budget.categoryId.equals(categoryId),
        ))
        .go();
  }

  Future<int> getMonthlyExpensesPaise(DateTime month) async {
    final start = _monthStart(month);
    final end = _nextMonthStart(month);
    final expenses =
        await (database.select(database.moneyTransactions)..where(
              (transaction) =>
                  transaction.transactionType.equals('expense') &
                  transaction.transactionDate.isBiggerOrEqualValue(start) &
                  transaction.transactionDate.isSmallerThanValue(end),
            ))
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
    final expenses =
        await (database.select(database.moneyTransactions)..where(
              (transaction) =>
                  transaction.transactionType.equals('expense') &
                  transaction.categoryId.equals(categoryId) &
                  transaction.transactionDate.isBiggerOrEqualValue(start) &
                  transaction.transactionDate.isSmallerThanValue(end),
            ))
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
      final amounts = await getMonthlyBudgetRolloverAmounts(month);
      final budget = await getMonthlyBudget(month);
      final expenses =
          amounts?.expensesPaise ?? await getMonthlyExpensesPaise(month);

      history.add(
        MonthlyBudgetHistoryItem(
          month: month,
          budgetPaise: budget?.limitPaise,
          availableBudgetPaise: amounts?.availableBudgetPaise ?? 0,
          rolloverPaise: amounts?.rolloverPaise ?? 0,
          rolloverEnabled: budget?.rolloverEnabled ?? false,
          expensesPaise: expenses,
        ),
      );
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

  Future<MonthlyBudgetSummary?> getMonthlyBudgetSummary(DateTime month) async {
    final amounts = await getMonthlyBudgetRolloverAmounts(month);
    if (amounts == null) return null;
    final budget = await getMonthlyBudget(month);
    if (budget == null) return null;

    final template = await getBudgetTemplate(categoryId: null);
    return MonthlyBudgetSummary(
      budgetPaise: amounts.baseBudgetPaise,
      availableBudgetPaise: amounts.availableBudgetPaise,
      rolloverPaise: amounts.rolloverPaise,
      rolloverEnabled: budget.rolloverEnabled,
      repeatsMonthly:
          template != null &&
          template.isActive &&
          !_monthStart(template.startMonth).isAfter(_monthStart(month)),
      expensesPaise: amounts.expensesPaise,
      remainingPaise: amounts.remainingPaise,
    );
  }

  Future<List<CategoryBudgetSummary>> getCategoryBudgetSummaries(
    DateTime month,
  ) async {
    final categories =
        await (database.select(database.categories)
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
          : await getCategoryBudget(month: month, categoryId: category.id);
      final template = await getBudgetTemplate(categoryId: category.id);
      final expenses =
          amounts?.expensesPaise ??
          await getCategoryExpensesPaise(month: month, categoryId: category.id);

      // A hidden category only stays on the budget screen while it still
      // has a budget, a monthly template or spending in this month.
      if (category.isArchived &&
          amounts == null &&
          (template == null || !template.isActive) &&
          expenses == 0) {
        continue;
      }

      results.add(
        CategoryBudgetSummary(
          category: category,
          budgetPaise: amounts?.baseBudgetPaise ?? 0,
          availableBudgetPaise: amounts?.availableBudgetPaise ?? 0,
          rolloverPaise: amounts?.rolloverPaise ?? 0,
          rolloverEnabled: budget?.rolloverEnabled ?? false,
          repeatsMonthly:
              template != null &&
              template.isActive &&
              !_monthStart(template.startMonth).isAfter(_monthStart(month)),
          expensesPaise: expenses,
        ),
      );
    }
    return results;
  }
}
