import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/budget_forecast.dart';

void main() {
  group('BudgetForecastCalculator', () {
    final april = DateTime(2027, 4, 1);

    test('projects month-end spending from the elapsed-day average', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 100000,
        spentToDatePaise: 12000,
      );

      expect(result.projectedSpendPaise, 36000);
      expect(result.daysElapsed, 10);
      expect(result.daysRemaining, 21);
      expect(result.recommendedDailySpendPaise, 4190);
      expect(result.status, BudgetForecastStatus.onTrack);
    });

    test('flags a forecast that is approaching the available budget', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 100000,
        spentToDatePaise: 30000,
      );

      expect(result.projectedSpendPaise, 90000);
      expect(result.status, BudgetForecastStatus.approachingLimit);
    });

    test('flags likely overspending and gives a daily spending guide', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 100000,
        spentToDatePaise: 40000,
      );

      expect(result.projectedSpendPaise, 120000);
      expect(result.projectedOverBudgetPaise, 20000);
      expect(result.recommendedDailySpendPaise, 2857);
      expect(result.status, BudgetForecastStatus.likelyOverBudget);
    });

    test('does not project before three elapsed days', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 2),
        budgetPaise: 100000,
        spentToDatePaise: 5000,
      );

      expect(result.projectedSpendPaise, isNull);
      expect(result.status, BudgetForecastStatus.insufficientData);
      expect(result.recommendedDailySpendPaise, 4750);
    });

    test('identifies a budget that has already been exceeded', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 100000,
        spentToDatePaise: 120000,
      );

      expect(result.projectedSpendPaise, 360000);
      expect(result.alreadyOverBudgetPaise, 20000);
      expect(result.recommendedDailySpendPaise, 0);
      expect(result.status, BudgetForecastStatus.alreadyOverBudget);
    });

    test('handles months with no spending yet', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 100000,
        spentToDatePaise: 0,
      );

      expect(result.projectedSpendPaise, isNull);
      expect(result.status, BudgetForecastStatus.noSpending);
      expect(result.recommendedDailySpendPaise, 4761);
    });

    test('uses the actual recorded spend on the final calendar day', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 30),
        budgetPaise: 100000,
        spentToDatePaise: 65000,
      );

      expect(result.projectedSpendPaise, 65000);
      expect(result.daysRemaining, 1);
      expect(result.recommendedDailySpendPaise, 35000);
    });

    test('returns no daily guide when a budget has not been set', () {
      final result = BudgetForecastCalculator.calculate(
        month: april,
        asOf: DateTime(2027, 4, 10),
        budgetPaise: 0,
        spentToDatePaise: 1000,
      );

      expect(result.status, BudgetForecastStatus.noBudget);
      expect(result.projectedSpendPaise, isNull);
      expect(result.recommendedDailySpendPaise, isNull);
    });

    test('rejects a forecast date outside the selected month', () {
      expect(
        () => BudgetForecastCalculator.calculate(
          month: april,
          asOf: DateTime(2027, 5, 1),
          budgetPaise: 100000,
          spentToDatePaise: 1000,
        ),
        throwsArgumentError,
      );
    });
  });
}
