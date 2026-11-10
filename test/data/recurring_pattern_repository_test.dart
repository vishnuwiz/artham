import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/recurring_transaction_repository.dart';

void main() {
  late AppDatabase database;
  late RecurringTransactionRepository repository;
  late int accountId;
  late int categoryId;
  late int merchantId;

  Future<void> addPayment(DateTime date, {int amountPaise = 14900}) async {
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            amountPaise: amountPaise,
            transactionType: 'expense',
            transactionDate: date,
            description: const Value('UPI payment Netflix'),
            source: const Value('sms'),
          ),
        );
  }

  Future<void> addMonthlyHistory() async {
    await addPayment(DateTime(2026, 8, 5));
    await addPayment(DateTime(2026, 9, 5));
    await addPayment(DateTime(2026, 10, 5));
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RecurringTransactionRepository(database);

    accountId = await database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Federal Bank',
            accountName: 'Account 6983',
            accountNumberLast4: const Value('6983'),
            openingBalancePaise: 1000000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Entertainment',
            type: 'expense',
          ),
        );

    merchantId = await database.into(database.merchants).insert(
          MerchantsCompanion.insert(
            name: 'Netflix',
            defaultCategoryId: Value(categoryId),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('returns a reviewable suggestion with account and category labels',
      () async {
    await addMonthlyHistory();

    final suggestions = await repository.getPatternSuggestions(
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.description, 'Netflix');
    expect(suggestions.single.categoryName, 'Entertainment');
    expect(
      suggestions.single.accountLabel,
      'Federal Bank · •••• 6983',
    );
    expect(suggestions.single.amountPaise, 14900);
    expect(suggestions.single.frequency, 'monthly');
    expect(suggestions.single.nextExpectedDate, DateTime(2026, 11, 5));
  });

  test('does not suggest a pattern already covered by a schedule', () async {
    await addMonthlyHistory();

    await database.into(database.recurringSchedules).insert(
          RecurringSchedulesCompanion.insert(
            accountId: accountId,
            categoryId: categoryId,
            amountPaise: 14900,
            transactionType: 'expense',
            frequency: 'monthly',
            startDate: DateTime(2026, 11, 5),
            nextDueDate: DateTime(2026, 11, 5),
            description: const Value('Netflix Subscription'),
            isActive: const Value(false),
          ),
        );

    final suggestions = await repository.getPatternSuggestions(
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });

  test('does not suggest a pattern for an inactive account', () async {
    await addMonthlyHistory();
    await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(const BankAccountsCompanion(isActive: Value(false)));

    final suggestions = await repository.getPatternSuggestions(
      asOf: DateTime(2026, 11, 1),
    );

    expect(suggestions, isEmpty);
  });
}
