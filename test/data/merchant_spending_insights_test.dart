import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/merchant_spending_insights.dart';

void main() {
  group('MerchantSpendingAnalyzer', () {
    final asOf = DateTime(2026, 11, 10, 12);

    List<MerchantExpenseRecord> amazonHistory({
      int currentAmountPaise = 200000,
    }) {
      return [
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 8, 10),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 9, 10),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 10, 10),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: currentAmountPaise,
          transactionDate: DateTime(2026, 11, 10),
        ),
      ];
    }

    test('ranks recognised merchants by current-month spend', () {
      final expenses = [
        ...amazonHistory(),
        MerchantExpenseRecord(
          merchantId: 2,
          merchantName: 'Swiggy',
          categoryName: 'Food & Dining',
          amountPaise: 50000,
          transactionDate: DateTime(2026, 11, 9),
        ),
      ];

      final result = MerchantSpendingAnalyzer.calculate(
        expenses: expenses,
        asOf: asOf,
      );

      expect(result.topMerchants.map((item) => item.merchantName), [
        'Amazon',
        'Swiggy',
      ]);
      expect(result.topMerchants.first.currentMonthSpendPaise, 200000);
      expect(result.topMerchants.first.currentMonthTransactionCount, 1);
    });

    test('flags spend over 50 percent and at least 500 rupees above usual', () {
      final result = MerchantSpendingAnalyzer.calculate(
        expenses: amazonHistory(),
        asOf: asOf,
      );

      expect(result.unusualMerchants, hasLength(1));
      expect(result.unusualMerchants.single.merchantName, 'Amazon');
      expect(result.unusualMerchants.single.expectedSpendToDatePaise, 100000);
      expect(result.unusualMerchants.single.percentageAboveUsual, 100);
    });

    test('does not flag a normal increase below the absolute threshold', () {
      final result = MerchantSpendingAnalyzer.calculate(
        expenses: amazonHistory(currentAmountPaise: 120000),
        asOf: asOf,
      );

      expect(result.topMerchants, hasLength(1));
      expect(result.unusualMerchants, isEmpty);
    });

    test('requires historical payments across at least two months', () {
      final expenses = [
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 10, 5),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 10, 7),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 100000,
          transactionDate: DateTime(2026, 10, 9),
        ),
        MerchantExpenseRecord(
          merchantId: 1,
          merchantName: 'Amazon',
          categoryName: 'Shopping',
          amountPaise: 500000,
          transactionDate: DateTime(2026, 11, 10),
        ),
      ];

      final result = MerchantSpendingAnalyzer.calculate(
        expenses: expenses,
        asOf: asOf,
      );

      expect(result.unusualMerchants, isEmpty);
    });

    test('ignores future-dated transactions and nonpositive amounts', () {
      final result = MerchantSpendingAnalyzer.calculate(
        expenses: [
          ...amazonHistory(),
          MerchantExpenseRecord(
            merchantId: 1,
            merchantName: 'Amazon',
            categoryName: 'Shopping',
            amountPaise: 900000,
            transactionDate: DateTime(2026, 11, 11),
          ),
          MerchantExpenseRecord(
            merchantId: 2,
            merchantName: 'Other',
            categoryName: 'Shopping',
            amountPaise: 0,
            transactionDate: DateTime(2026, 11, 10),
          ),
        ],
        asOf: asOf,
      );

      expect(result.topMerchants.first.currentMonthSpendPaise, 200000);
      expect(
        result.topMerchants.any((item) => item.merchantName == 'Other'),
        isFalse,
      );
    });

    test('respects the requested merchant limit', () {
      final result = MerchantSpendingAnalyzer.calculate(
        expenses: [
          ...amazonHistory(),
          MerchantExpenseRecord(
            merchantId: 2,
            merchantName: 'Swiggy',
            amountPaise: 50000,
            transactionDate: DateTime(2026, 11, 9),
          ),
        ],
        asOf: asOf,
        limit: 1,
      );

      expect(result.topMerchants, hasLength(1));
    });
  });
}
