/// A month-end spending estimate for one overall or category budget.
enum BudgetForecastStatus {
  noBudget,
  noSpending,
  insufficientData,
  onTrack,
  approachingLimit,
  likelyOverBudget,
  alreadyOverBudget,
}

class BudgetForecast {
  final int budgetPaise;
  final int spentToDatePaise;
  final int daysElapsed;
  final int daysRemaining;
  final int daysInMonth;
  final int? projectedSpendPaise;
  final int? recommendedDailySpendPaise;
  final BudgetForecastStatus status;

  const BudgetForecast({
    required this.budgetPaise,
    required this.spentToDatePaise,
    required this.daysElapsed,
    required this.daysRemaining,
    required this.daysInMonth,
    required this.projectedSpendPaise,
    required this.recommendedDailySpendPaise,
    required this.status,
  });

  int get remainingBudgetPaise => budgetPaise - spentToDatePaise;

  int get projectedOverBudgetPaise {
    final projected = projectedSpendPaise;
    if (projected == null || projected <= budgetPaise) return 0;
    return projected - budgetPaise;
  }

  int get alreadyOverBudgetPaise =>
      remainingBudgetPaise < 0 ? -remainingBudgetPaise : 0;

  bool get hasProjection => projectedSpendPaise != null;
}

/// Calculates a transparent straight-line forecast from spending recorded
/// so far in the selected month. The current day is included in both the
/// elapsed-day calculation and the daily spending guide.
class BudgetForecastCalculator {
  static const int minimumDaysForProjection = 3;
  static const int approachingLimitPercent = 90;

  static BudgetForecast calculate({
    required DateTime month,
    required DateTime asOf,
    required int budgetPaise,
    required int spentToDatePaise,
  }) {
    if (budgetPaise < 0) {
      throw ArgumentError.value(
        budgetPaise,
        'budgetPaise',
        'Budget cannot be negative.',
      );
    }
    if (spentToDatePaise < 0) {
      throw ArgumentError.value(
        spentToDatePaise,
        'spentToDatePaise',
        'Recorded spending cannot be negative.',
      );
    }
    if (month.year != asOf.year || month.month != asOf.month) {
      throw ArgumentError(
        'The forecast month and as-of date must be in the same month.',
      );
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysElapsed = asOf.day.clamp(1, daysInMonth).toInt();
    // Includes today, because the user can still spend during the current day.
    final daysRemaining = daysInMonth - daysElapsed + 1;

    final int? projectedSpend;
    if (budgetPaise > 0 &&
        spentToDatePaise > 0 &&
        daysElapsed >= minimumDaysForProjection) {
      // Integer arithmetic keeps the calculation deterministic in paise.
      projectedSpend =
          (spentToDatePaise * daysInMonth + daysElapsed ~/ 2) ~/ daysElapsed;
    } else {
      projectedSpend = null;
    }

    final int? recommendedDailySpend;
    if (budgetPaise == 0) {
      recommendedDailySpend = null;
    } else {
      final remaining = budgetPaise - spentToDatePaise;
      recommendedDailySpend = remaining > 0
          ? remaining ~/ daysRemaining
          : 0;
    }

    final BudgetForecastStatus status;
    if (budgetPaise == 0) {
      status = BudgetForecastStatus.noBudget;
    } else if (spentToDatePaise == 0) {
      status = BudgetForecastStatus.noSpending;
    } else if (spentToDatePaise > budgetPaise) {
      status = BudgetForecastStatus.alreadyOverBudget;
    } else if (projectedSpend == null) {
      status = BudgetForecastStatus.insufficientData;
    } else if (projectedSpend > budgetPaise) {
      status = BudgetForecastStatus.likelyOverBudget;
    } else if (projectedSpend * 100 >=
        budgetPaise * approachingLimitPercent) {
      status = BudgetForecastStatus.approachingLimit;
    } else {
      status = BudgetForecastStatus.onTrack;
    }

    return BudgetForecast(
      budgetPaise: budgetPaise,
      spentToDatePaise: spentToDatePaise,
      daysElapsed: daysElapsed,
      daysRemaining: daysRemaining,
      daysInMonth: daysInMonth,
      projectedSpendPaise: projectedSpend,
      recommendedDailySpendPaise: recommendedDailySpend,
      status: status,
    );
  }
}
