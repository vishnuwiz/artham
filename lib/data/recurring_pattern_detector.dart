/// Conservative, on-device detection of likely recurring income and expenses.
///
/// The detector never writes to the database. It only returns suggestions for
/// the user to review; a schedule is created only after the user saves the
/// prefilled recurring-schedule form.
class RecurringPatternTransaction {
  final int accountId;
  final int categoryId;
  final int amountPaise;
  final String transactionType;
  final DateTime transactionDate;
  final String? description;
  final String? merchantName;
  final String source;

  const RecurringPatternTransaction({
    required this.accountId,
    required this.categoryId,
    required this.amountPaise,
    required this.transactionType,
    required this.transactionDate,
    this.description,
    this.merchantName,
    required this.source,
  });
}

class RecurringPatternSuggestion {
  final int accountId;
  final int categoryId;
  final int amountPaise;
  final String transactionType;
  final String frequency;
  final int interval;
  final String description;
  final String patternIdentity;
  final String accountLabel;
  final String categoryName;
  final int occurrenceCount;
  final DateTime lastOccurrence;
  final DateTime nextExpectedDate;

  const RecurringPatternSuggestion({
    required this.accountId,
    required this.categoryId,
    required this.amountPaise,
    required this.transactionType,
    required this.frequency,
    required this.interval,
    required this.description,
    required this.patternIdentity,
    required this.accountLabel,
    required this.categoryName,
    required this.occurrenceCount,
    required this.lastOccurrence,
    required this.nextExpectedDate,
  });
}

class RecurringPatternDetector {
  const RecurringPatternDetector();

  static const int minimumOccurrences = 3;
  static const int _lookbackDays = 800;

  /// Detects stable weekly, monthly, quarterly, half-yearly, or yearly
  /// patterns. Transfers, already-generated recurring entries, future-dated
  /// entries, and transactions without a usable category or payee are ignored.
  List<RecurringPatternSuggestion> detect(
    Iterable<RecurringPatternTransaction> transactions, {
    required DateTime asOf,
  }) {
    final today = _dateOnly(asOf);
    final earliest = today.subtract(const Duration(days: _lookbackDays));
    final groups = <String, List<RecurringPatternTransaction>>{};

    for (final transaction in transactions) {
      if (transaction.transactionType != 'income' &&
          transaction.transactionType != 'expense') {
        continue;
      }
      if (transaction.amountPaise <= 0 ||
          transaction.categoryId <= 0 ||
          transaction.accountId <= 0 ||
          transaction.source == 'recurring') {
        continue;
      }

      final date = _dateOnly(transaction.transactionDate);
      if (date.isBefore(earliest) || date.isAfter(today)) continue;

      final label = transaction.merchantName?.trim().isNotEmpty == true
          ? transaction.merchantName!.trim()
          : (transaction.description ?? '').trim();
      final identity = normalizeIdentity(label);
      if (identity.isEmpty) continue;

      final key = [
        transaction.accountId,
        transaction.transactionType,
        transaction.categoryId,
        identity,
      ].join('|');
      groups.putIfAbsent(key, () => []).add(transaction);
    }

    final suggestions = <RecurringPatternSuggestion>[];

    for (final entry in groups.entries) {
      // Multiple purchases from the same payee on one date count as one
      // occurrence, not as evidence of a recurring payment.
      final byDate = <int, RecurringPatternTransaction>{};
      for (final transaction in entry.value) {
        final date = _dateOnly(transaction.transactionDate);
        final key = date.year * 10000 + date.month * 100 + date.day;
        byDate.putIfAbsent(key, () => transaction);
      }

      final occurrences = byDate.values.toList()
        ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      if (occurrences.length < minimumOccurrences) continue;

      // Use a recent, bounded sample so older behaviour does not dominate.
      final recent = occurrences.length > 4
          ? occurrences.sublist(occurrences.length - 4)
          : occurrences;
      final amounts = recent.map((item) => item.amountPaise).toList();
      final typicalAmount = _median(amounts);
      final amountTolerance = _max(2000, (typicalAmount * 0.12).round());
      if (amounts.any(
        (amount) => (amount - typicalAmount).abs() > amountTolerance,
      )) {
        continue;
      }

      final gaps = <int>[];
      for (var index = 1; index < recent.length; index++) {
        gaps.add(
          _dateOnly(recent[index].transactionDate)
              .difference(_dateOnly(recent[index - 1].transactionDate))
              .inDays,
        );
      }

      final cadence = _inferCadence(gaps);
      if (cadence == null) continue;

      final lastOccurrence = _dateOnly(recent.last.transactionDate);
      final nextExpected = _nextOccurrence(
        lastOccurrence,
        cadence.frequency,
        cadence.interval,
      );
      final graceDays = cadence.frequency == 'weekly'
          ? 14
          : cadence.frequency == 'yearly'
              ? 60
              : 45;
      if (nextExpected.isBefore(
        today.subtract(Duration(days: graceDays)),
      )) {
        continue;
      }

      final parts = entry.key.split('|');
      final label = recent.last.merchantName?.trim().isNotEmpty == true
          ? recent.last.merchantName!.trim()
          : (recent.last.description ?? '').trim();

      suggestions.add(
        RecurringPatternSuggestion(
          accountId: recent.last.accountId,
          categoryId: recent.last.categoryId,
          amountPaise: typicalAmount,
          transactionType: recent.last.transactionType,
          frequency: cadence.frequency,
          interval: cadence.interval,
          description: label,
          patternIdentity: parts.skip(3).join('|'),
          accountLabel: '',
          categoryName: '',
          occurrenceCount: recent.length,
          lastOccurrence: lastOccurrence,
          nextExpectedDate: nextExpected,
        ),
      );
    }

    suggestions.sort(
      (a, b) => a.nextExpectedDate.compareTo(b.nextExpectedDate),
    );
    return suggestions;
  }

  /// Normalizes merchant/description labels for grouping and schedule matching.
  static String normalizeIdentity(String value) {
    const ignoredTokens = {
      'upi',
      'dr',
      'cr',
      'debit',
      'credit',
      'payment',
      'paid',
      'txn',
      'transaction',
      'ref',
      'reference',
      'no',
      'id',
      'from',
      'to',
      'via',
    };

    final tokens = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) =>
            token.isNotEmpty &&
            !ignoredTokens.contains(token) &&
            !RegExp(r'^\d+

    return tokens.join(' ').trim();
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }

  static _RecurringCadence? _inferCadence(List<int> gaps) {
    // Check monthly cadences first: a payment every 28-31 days is more
    // naturally represented as monthly than as every four weeks.
    for (var months = 1; months <= 6; months++) {
      final expectedDays = 30.4375 * months;
      final tolerance = _max(5, (months * 1.25).round());
      if (gaps.every((gap) => (gap - expectedDays).abs() <= tolerance)) {
        return _RecurringCadence('monthly', months);
      }
    }

    if (gaps.every((gap) => gap >= 350 && gap <= 380)) {
      return const _RecurringCadence('yearly', 1);
    }

    for (var weeks = 1; weeks <= 3; weeks++) {
      final expectedDays = weeks * 7;
      if (gaps.every((gap) => (gap - expectedDays).abs() <= 1)) {
        return _RecurringCadence('weekly', weeks);
      }
    }

    return null;
  }

  static DateTime _nextOccurrence(
    DateTime current,
    String frequency,
    int interval,
  ) {
    if (frequency == 'weekly') {
      return current.add(Duration(days: 7 * interval));
    }

    final targetYear = frequency == 'yearly' ? current.year + interval : current.year;
    final targetMonth = frequency == 'monthly'
        ? current.month + interval
        : current.month;
    final firstOfTargetMonth = DateTime(targetYear, targetMonth, 1);
    final lastDay = DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month + 1,
      0,
    ).day;
    final day = current.day > lastDay ? lastDay : current.day;
    return DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      day,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _max(int first, int second) => first > second ? first : second;
}

class _RecurringCadence {
  final String frequency;
  final int interval;

  const _RecurringCadence(this.frequency, this.interval);
}
).hasMatch(token) &&
            !RegExp(r'^(ref|id|txn|utr)\d+

    return tokens.join(' ').trim();
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }

  static _RecurringCadence? _inferCadence(List<int> gaps) {
    // Check monthly cadences first: a payment every 28-31 days is more
    // naturally represented as monthly than as every four weeks.
    for (var months = 1; months <= 6; months++) {
      final expectedDays = 30.4375 * months;
      final tolerance = _max(5, (months * 1.25).round());
      if (gaps.every((gap) => (gap - expectedDays).abs() <= tolerance)) {
        return _RecurringCadence('monthly', months);
      }
    }

    if (gaps.every((gap) => gap >= 350 && gap <= 380)) {
      return const _RecurringCadence('yearly', 1);
    }

    for (var weeks = 1; weeks <= 3; weeks++) {
      final expectedDays = weeks * 7;
      if (gaps.every((gap) => (gap - expectedDays).abs() <= 1)) {
        return _RecurringCadence('weekly', weeks);
      }
    }

    return null;
  }

  static DateTime _nextOccurrence(
    DateTime current,
    String frequency,
    int interval,
  ) {
    if (frequency == 'weekly') {
      return current.add(Duration(days: 7 * interval));
    }

    final targetYear = frequency == 'yearly' ? current.year + interval : current.year;
    final targetMonth = frequency == 'monthly'
        ? current.month + interval
        : current.month;
    final firstOfTargetMonth = DateTime(targetYear, targetMonth, 1);
    final lastDay = DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month + 1,
      0,
    ).day;
    final day = current.day > lastDay ? lastDay : current.day;
    return DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      day,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _max(int first, int second) => first > second ? first : second;
}

class _RecurringCadence {
  final String frequency;
  final int interval;

  const _RecurringCadence(this.frequency, this.interval);
}
).hasMatch(token));

    return tokens.join(' ').trim();
  }

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }

  static _RecurringCadence? _inferCadence(List<int> gaps) {
    // Check monthly cadences first: a payment every 28-31 days is more
    // naturally represented as monthly than as every four weeks.
    for (var months = 1; months <= 6; months++) {
      final expectedDays = 30.4375 * months;
      final tolerance = _max(5, (months * 1.25).round());
      if (gaps.every((gap) => (gap - expectedDays).abs() <= tolerance)) {
        return _RecurringCadence('monthly', months);
      }
    }

    if (gaps.every((gap) => gap >= 350 && gap <= 380)) {
      return const _RecurringCadence('yearly', 1);
    }

    for (var weeks = 1; weeks <= 3; weeks++) {
      final expectedDays = weeks * 7;
      if (gaps.every((gap) => (gap - expectedDays).abs() <= 1)) {
        return _RecurringCadence('weekly', weeks);
      }
    }

    return null;
  }

  static DateTime _nextOccurrence(
    DateTime current,
    String frequency,
    int interval,
  ) {
    if (frequency == 'weekly') {
      return current.add(Duration(days: 7 * interval));
    }

    final targetYear = frequency == 'yearly' ? current.year + interval : current.year;
    final targetMonth = frequency == 'monthly'
        ? current.month + interval
        : current.month;
    final firstOfTargetMonth = DateTime(targetYear, targetMonth, 1);
    final lastDay = DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month + 1,
      0,
    ).day;
    final day = current.day > lastDay ? lastDay : current.day;
    return DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      day,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _max(int first, int second) => first > second ? first : second;
}

class _RecurringCadence {
  final String frequency;
  final int interval;

  const _RecurringCadence(this.frequency, this.interval);
}
