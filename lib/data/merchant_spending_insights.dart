/// Merchant-level spending analytics derived from the local transaction history.
///
/// Unusual-spend flags require three distinct historical payment dates across
/// at least two months. Current month-to-date spend is compared with the
/// average through the same day of the month in the previous three months.
class MerchantExpenseRecord {
  final int merchantId;
  final String merchantName;
  final String? categoryName;
  final int amountPaise;
  final DateTime transactionDate;

  const MerchantExpenseRecord({
    required this.merchantId,
    required this.merchantName,
    required this.amountPaise,
    required this.transactionDate,
    this.categoryName,
  });
}

class MerchantSpendingItem {
  final int merchantId;
  final String merchantName;
  final String? categoryName;
  final int currentMonthSpendPaise;
  final int currentMonthTransactionCount;
  final int expectedSpendToDatePaise;
  final int historicalPaymentDateCount;
  final int historicalMonthCount;

  const MerchantSpendingItem({
    required this.merchantId,
    required this.merchantName,
    required this.categoryName,
    required this.currentMonthSpendPaise,
    required this.currentMonthTransactionCount,
    required this.expectedSpendToDatePaise,
    required this.historicalPaymentDateCount,
    required this.historicalMonthCount,
  });

  int get excessSpendPaise =>
      currentMonthSpendPaise - expectedSpendToDatePaise;

  int get percentageAboveUsual {
    if (expectedSpendToDatePaise <= 0) return 0;
    return (excessSpendPaise * 100 / expectedSpendToDatePaise).round();
  }

  bool get isUnusual =>
      expectedSpendToDatePaise > 0 &&
      historicalPaymentDateCount >=
          MerchantSpendingAnalyzer.minimumHistoricalPaymentDates &&
      historicalMonthCount >=
          MerchantSpendingAnalyzer.minimumHistoricalMonths &&
      currentMonthSpendPaise * 2 > expectedSpendToDatePaise * 3 &&
      excessSpendPaise >= MerchantSpendingAnalyzer.minimumExcessPaise;
}

class MerchantSpendingInsights {
  final List<MerchantSpendingItem> topMerchants;
  final List<MerchantSpendingItem> unusualMerchants;

  const MerchantSpendingInsights({
    this.topMerchants = const [],
    this.unusualMerchants = const [],
  });

  factory MerchantSpendingInsights.empty() =>
      const MerchantSpendingInsights();
}

class MerchantSpendingAnalyzer {
  static const int historyMonths = 3;
  static const int minimumHistoricalPaymentDates = 3;
  static const int minimumHistoricalMonths = 2;
  static const int minimumExcessPaise = 50000;

  static MerchantSpendingInsights calculate({
    required List<MerchantExpenseRecord> expenses,
    required DateTime asOf,
    int limit = 5,
  }) {
    if (limit <= 0) return const MerchantSpendingInsights();

    final currentMonth = DateTime(asOf.year, asOf.month, 1);
    final nextMonth = DateTime(asOf.year, asOf.month + 1, 1);
    final historyStart = DateTime(
      asOf.year,
      asOf.month - historyMonths,
      1,
    );
    final byMerchant = <int, List<MerchantExpenseRecord>>{};

    for (final expense in expenses) {
      if (expense.amountPaise <= 0 ||
          expense.merchantName.trim().isEmpty ||
          expense.transactionDate.isAfter(asOf) ||
          expense.transactionDate.isBefore(historyStart) ||
          !expense.transactionDate.isBefore(nextMonth)) {
        continue;
      }
      byMerchant.putIfAbsent(expense.merchantId, () => []).add(expense);
    }

    final summaries = <MerchantSpendingItem>[];
    for (final entry in byMerchant.entries) {
      final records = entry.value;
      var currentSpend = 0;
      var currentCount = 0;
      final historicalPaymentDates = <DateTime>{};
      final historicalMonths = <DateTime>{};
      final historicalSpendByMonth = <DateTime, int>{};
      String? currentCategory;
      DateTime? latestCurrentDate;

      for (final record in records) {
        final date = record.transactionDate;
        if (!date.isBefore(currentMonth)) {
          currentSpend += record.amountPaise;
          currentCount++;
          if (record.categoryName != null &&
              (latestCurrentDate == null ||
                  !date.isBefore(latestCurrentDate))) {
            currentCategory = record.categoryName;
            latestCurrentDate = date;
          }
          continue;
        }

        final monthStart = DateTime(date.year, date.month, 1);
        historicalMonths.add(monthStart);
        historicalPaymentDates.add(DateTime(date.year, date.month, date.day));

        // Same-day-of-month comparison avoids flagging a normal monthly
        // subscription simply because its payment exceeds a daily average.
        if (date.day <= asOf.day) {
          historicalSpendByMonth[monthStart] =
              (historicalSpendByMonth[monthStart] ?? 0) +
              record.amountPaise;
        }
      }

      if (currentCount == 0) continue;

      var expectedSpend = 0;
      for (var offset = 1; offset <= historyMonths; offset++) {
        final month = DateTime(asOf.year, asOf.month - offset, 1);
        expectedSpend += historicalSpendByMonth[month] ?? 0;
      }
      expectedSpend = (expectedSpend / historyMonths).round();

      summaries.add(
        MerchantSpendingItem(
          merchantId: entry.key,
          merchantName: records.first.merchantName,
          categoryName: currentCategory,
          currentMonthSpendPaise: currentSpend,
          currentMonthTransactionCount: currentCount,
          expectedSpendToDatePaise: expectedSpend,
          historicalPaymentDateCount: historicalPaymentDates.length,
          historicalMonthCount: historicalMonths.length,
        ),
      );
    }

    summaries.sort((a, b) {
      final spendOrder = b.currentMonthSpendPaise.compareTo(
        a.currentMonthSpendPaise,
      );
      return spendOrder != 0
          ? spendOrder
          : a.merchantName.compareTo(b.merchantName);
    });

    final unusual = summaries.where((item) => item.isUnusual).toList()
      ..sort((a, b) => b.excessSpendPaise.compareTo(a.excessSpendPaise));

    return MerchantSpendingInsights(
      topMerchants: summaries.take(limit).toList(),
      unusualMerchants: unusual.take(limit).toList(),
    );
  }
}
