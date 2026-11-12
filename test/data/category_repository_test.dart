import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/category_catalog.dart';
import 'package:artham/data/repositories/category_repository.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = CategoryRepository(database);
  });

  tearDown(() => database.close());

  Future<List<String>> names(
    String type, {
    bool includeArchived = false,
  }) async => (await repository.getCategories(
    type,
    includeArchived: includeArchived,
  )).map((item) => item.name).toList();

  Future<int> addTransaction(int categoryId) async {
    final accountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'SBI',
            accountName: 'Account',
            openingBalancePaise: 0,
            openingDate: DateTime(2026, 11, 1),
          ),
        );
    return database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: 10000,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 5),
          ),
        );
  }

  test(
    'seeds every requested default category with a Material icon key',
    () async {
      await repository.ensureDefaultCategories();

      final all = {...await names('expense'), ...await names('income')};
      const requested = [
        'Investment',
        'Income',
        'Personal',
        'Work',
        'Business',
        'Restaurants',
        'Housing',
        'Electricity',
        'Transport & Fuel',
        'Food & Grocery',
        'Medical',
        'Travel',
        'Fitness',
        'Insurance',
        'Entertainment',
        'Internet & Telecom',
        'Gift',
        'Taxes',
        'Utility',
        'Shopping',
        'Card Repayment',
        'ATM',
        'Bank Charges',
        'Reimbursement',
        'Self Transfer',
        'Loan',
        'Education',
      ];
      expect(all, containsAll(requested));

      final rows = await database.select(database.categories).get();
      expect(rows, hasLength(defaultCategoryCatalog.length));
      for (final row in rows) {
        expect(row.iconKey, isNotNull, reason: row.name);
        expect(row.seedKey, isNotNull, reason: row.name);
        expect(row.isSystem, isTrue);
      }
    },
  );

  test('seeding again does not duplicate categories', () async {
    await repository.ensureDefaultCategories();
    await repository.ensureDefaultCategories();

    final rows = await database.select(database.categories).get();
    expect(rows, hasLength(defaultCategoryCatalog.length));
  });

  test('a renamed default is not re-created by seeding', () async {
    await repository.ensureDefaultCategories();
    final atm = (await repository.getCategories('expense'))
        .firstWhere((item) => item.name == 'ATM');

    await repository.updateCategory(
      id: atm.id,
      name: 'Cash',
      iconKey: 'local_atm',
      colorHex: '#8FE3C4',
    );
    await repository.ensureDefaultCategories();

    final expense = await names('expense');
    expect(expense, contains('Cash'));
    expect(expense, isNot(contains('ATM')));
  });

  test('creates a custom category and rejects a duplicate name', () async {
    await repository.ensureDefaultCategories();

    await repository.createCategory(
      name: '  Pet   care ',
      type: 'expense',
      iconKey: 'pets',
      colorHex: '#F5A5D6',
    );
    expect(await names('expense'), contains('Pet care'));

    expect(
      () => repository.createCategory(
        name: 'pet care',
        type: 'expense',
        iconKey: 'pets',
        colorHex: '#F5A5D6',
      ),
      throwsA(isA<CategoryValidationException>()),
    );
    expect(
      () => repository.createCategory(
        name: '   ',
        type: 'expense',
        iconKey: 'pets',
        colorHex: '#F5A5D6',
      ),
      throwsA(isA<CategoryValidationException>()),
    );
  });

  test('the same name can exist once per type', () async {
    await repository.ensureDefaultCategories();
    expect(await names('expense'), contains('Gift'));
    expect(await names('income'), contains('Gift'));
  });

  test('deletes an unused custom category', () async {
    await repository.ensureDefaultCategories();
    final id = await repository.createCategory(
      name: 'Hobbies',
      type: 'expense',
      iconKey: 'music_note',
      colorHex: '#B9A5F5',
    );

    expect(await repository.deleteCategory(id), CategoryDeleteResult.deleted);
    expect(
      await names('expense', includeArchived: true),
      isNot(contains('Hobbies')),
    );
  });

  test('hides a category that transactions use, and keeps the link', () async {
    await repository.ensureDefaultCategories();
    final id = await repository.createCategory(
      name: 'Hobbies',
      type: 'expense',
      iconKey: 'music_note',
      colorHex: '#B9A5F5',
    );
    final transactionId = await addTransaction(id);

    expect(await repository.countTransactions(id), 1);
    expect(await repository.deleteCategory(id), CategoryDeleteResult.archived);
    expect(await names('expense'), isNot(contains('Hobbies')));
    expect(await names('expense', includeArchived: true), contains('Hobbies'));

    final transaction = await (database.select(
      database.moneyTransactions,
    )..where((row) => row.id.equals(transactionId))).getSingle();
    expect(transaction.categoryId, id);

    await repository.restoreCategory(id);
    expect(await names('expense'), contains('Hobbies'));
  });

  test('a removed default is hidden and stays hidden after seeding', () async {
    await repository.ensureDefaultCategories();
    final loan = (await repository.getCategories('expense'))
        .firstWhere((item) => item.name == 'Loan');

    expect(
      await repository.deleteCategory(loan.id),
      CategoryDeleteResult.archived,
    );
    await repository.ensureDefaultCategories();

    expect(await names('expense'), isNot(contains('Loan')));
  });

  test('creating a hidden category name brings it back', () async {
    await repository.ensureDefaultCategories();
    final loan = (await repository.getCategories('expense'))
        .firstWhere((item) => item.name == 'Loan');
    await repository.deleteCategory(loan.id);

    final id = await repository.createCategory(
      name: 'loan',
      type: 'expense',
      iconKey: 'request_quote',
      colorHex: '#FFD3A0',
    );

    expect(id, loan.id);
    expect(await names('expense'), contains('loan'));
  });

  test('keeps at least one category of each type', () async {
    final id = await repository.createCategory(
      name: 'Only one',
      type: 'income',
      iconKey: 'payments',
      colorHex: '#8FE3C4',
    );

    expect(
      () => repository.deleteCategory(id),
      throwsA(isA<CategoryValidationException>()),
    );
  });

  test('adopts a user category that already has a default name', () async {
    await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: 'fitness', type: 'expense'));

    await repository.ensureDefaultCategories();

    final fitness = (await repository.getCategories('expense'))
        .where((item) => item.name.toLowerCase() == 'fitness')
        .toList();
    expect(fitness, hasLength(1));
    expect(fitness.single.seedKey, 'expense.fitness');
    expect(fitness.single.iconKey, 'fitness_center');
  });
}
