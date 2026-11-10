import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/recurring_pattern_detector.dart';

void main() {
  const detector = RecurringPatternDetector();

  RecurringPatternTransaction transaction(
    DateTime date, {
    int amountPaise = 99900,
    int accountId = 1,
    String type = 'expense',
    String source = 'sms',
    String? merchant = 'Netflix',
    String? description = 'UPI payment Netflix',
  }) {
    return RecurringPatternTransaction(
      accountId: accountId,
      categoryId: 4,
      amountPaise: amountPaise,
      transactionType: type,
      transactionDate: date,
      description: description,
      merchantName: merchant,
      source: source,
    );
  }

  test('detects a stable monthly payment and predicts its next date', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 8, 5)),
        transaction(DateTime(2026, 9, 5)),
        transaction(DateTime(2026, 10, 5)),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.frequency, 'monthly');
    expect(suggestions.single.interval, 1);
    expect(suggestions.single.amountPaise, 99900);
    expect(suggestions.single.occurrenceCount, 3);
    expect(suggestions.single.description, 'Netflix');
    expect(suggestions.single.nextExpectedDate, DateTime(2026, 11, 5));
  });

  test('detects a fortnightly payment as every two weeks', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 10, 1)),
        transaction(DateTime(2026, 10, 15)),
        transaction(DateTime(2026, 10, 29)),
      ],
      asOf: DateTime(2026, 10, 30),
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.frequency, 'weekly');
    expect(suggestions.single.interval, 2);
    expect(suggestions.single.nextExpectedDate, DateTime(2026, 11, 12));
  });

  test('requires at least three distinct transaction dates', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 9, 5)),
        transaction(DateTime(2026, 10, 5)),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('does not treat several same-day purchases as a recurring pattern', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 10, 5)),
        transaction(DateTime(2026, 10, 5), amountPaise: 100000),
        transaction(DateTime(2026, 10, 5), amountPaise: 105000),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('rejects unstable amounts', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 8, 5), amountPaise: 50000),
        transaction(DateTime(2026, 9, 5), amountPaise: 150000),
        transaction(DateTime(2026, 10, 5), amountPaise: 50000),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('rejects irregular transaction intervals', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 7, 1)),
        transaction(DateTime(2026, 8, 17)),
        transaction(DateTime(2026, 10, 5)),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('ignores transfers and transactions created by recurring schedules', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 8, 5), type: 'transfer'),
        transaction(DateTime(2026, 9, 5), source: 'recurring'),
        transaction(DateTime(2026, 10, 5)),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('keeps patterns from separate accounts separate', () {
    final suggestions = detector.detect(
      [
        transaction(DateTime(2026, 8, 5), accountId: 1),
        transaction(DateTime(2026, 9, 5), accountId: 1),
        transaction(DateTime(2026, 10, 5), accountId: 1),
        transaction(DateTime(2026, 8, 5), accountId: 2),
        transaction(DateTime(2026, 9, 5), accountId: 2),
      ],
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.accountId, 1);
  });

  test('normalizes bank alert noise without losing the merchant identity', () {
    expect(
      RecurringPatternDetector.normalizeIdentity('UPI/DR/123456/Netflix/REF987'),
      'netflix',
    );
  });
}
