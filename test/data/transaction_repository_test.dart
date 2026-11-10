import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase database;
  late TransactionRepository repository;
  late int accountId;
  late int selectedCategoryId;
  late int foodCategoryId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(database);

    accountId = await database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Federal Bank',
            accountName: 'Account 1255',
            accountNumberLast4: const Value('1255'),
            openingBalancePaise: 100000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    selectedCategoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Shopping',
            type: 'expense',
          ),
        );
    foodCategoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Food & Dining',
            type: 'expense',
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('links a recognised merchant without overriding the selected category',
      () async {
    final id = await repository.addTransaction(
      accountId: accountId,
      categoryId: selectedCategoryId,
      amountPaise: 45000,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 10),
      description: 'SWIGGY*ORDER123',
    );

    final transaction = await (database.select(database.moneyTransactions)
          ..where((row) => row.id.equals(id)))
        .getSingle();
    final merchant = await (database.select(database.merchants)
          ..where((row) => row.id.equals(transaction.merchantId!)))
        .getSingle();

    expect(transaction.categoryId, selectedCategoryId);
    expect(transaction.merchantId, isNotNull);
    expect(merchant.name, 'Swiggy');
    expect(merchant.defaultCategoryId, foodCategoryId);

    final recent = await repository.getRecentTransactions();
    expect(recent, hasLength(1));
    expect(recent.single.merchant?.name, 'Swiggy');
  });

  test('does not create a merchant record for an unknown description',
      () async {
    final id = await repository.addTransaction(
      accountId: accountId,
      categoryId: selectedCategoryId,
      amountPaise: 30000,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 10),
      description: 'Local stationery shop',
    );

    final transaction = await (database.select(database.moneyTransactions)
          ..where((row) => row.id.equals(id)))
        .getSingle();

    expect(transaction.merchantId, isNull);
    expect(await database.select(database.merchants).get(), isEmpty);
  });

  test('removes merchant link when an edited description is unrecognised',
      () async {
    final id = await repository.addTransaction(
      accountId: accountId,
      categoryId: foodCategoryId,
      amountPaise: 45000,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 10),
      description: 'Swiggy order',
    );

    await repository.updateTransaction(
      transactionId: id,
      accountId: accountId,
      categoryId: selectedCategoryId,
      amountPaise: 45000,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 10),
      description: 'Local shop',
    );

    final transaction = await (database.select(database.moneyTransactions)
          ..where((row) => row.id.equals(id)))
        .getSingle();

    expect(transaction.merchantId, isNull);
  });
}
