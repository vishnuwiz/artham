import 'dart:io';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/transaction_repository.dart';
import 'package:artham/data/split/split_repository.dart';
import 'package:artham/data/split/split_sources.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  late AppDatabase database;
  late Directory documents;
  late SplitRepository repo;
  late int accountId;
  late int categoryId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('artham-split-test-');
    repo = SplitRepository(
      database,
      documentsDirectoryProvider: () async => documents,
      clock: () => today,
    );
    accountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'Test Bank',
            accountName: 'Main',
            openingBalancePaise: 1000000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    categoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: 'Food', type: 'expense'));
  });

  tearDown(() async {
    await database.close();
    await documents.delete(recursive: true);
  });

  Future<List<MoneyTransaction>> allTransactions() =>
      database.select(database.moneyTransactions).get();

  test('a split records your share as spending and the rest as lent', () async {
    final meera = await repo.addPerson('Meera');
    final arjun = await repo.addPerson('Arjun');

    await repo.addSplitExpense(
      title: 'Team lunch',
      totalPaise: 240000,
      accountId: accountId,
      categoryId: categoryId,
      date: today,
      shares: [
        const SplitShare(personId: null, paise: 80000),
        SplitShare(personId: meera.id, paise: 80000),
        SplitShare(personId: arjun.id, paise: 80000),
      ],
    );

    final rows = await allTransactions();
    expect(rows, hasLength(2));
    final mine = rows.firstWhere((r) => r.source == 'manual');
    final lent = rows.firstWhere((r) => r.source == kSplitLentSource);
    expect(mine.amountPaise, 80000);
    expect(mine.categoryId, categoryId);
    expect(lent.amountPaise, 160000);
    expect(lent.categoryId, isNull);

    final ledger = repo.ledger.value;
    expect(ledger.balanceFor(meera.id), 80000);
    expect(ledger.totalOwedToYou, 160000);

    // The account paid the full bill, but only your share is spending.
    final summary = await TransactionRepository(database).getBalanceSummary();
    expect(summary.monthlyExpensesPaise, 80000);
  });

  test('settling clears the balance without counting as income', () async {
    final meera = await repo.addPerson('Meera');
    await repo.addSplitExpense(
      title: 'Cab',
      totalPaise: 80000,
      accountId: accountId,
      categoryId: categoryId,
      date: today,
      shares: [
        const SplitShare(personId: null, paise: 40000),
        SplitShare(personId: meera.id, paise: 40000),
      ],
    );
    await repo.settle(
      personId: meera.id,
      amountPaise: 40000,
      receivedFromThem: true,
      accountId: accountId,
      date: today,
    );

    expect(repo.ledger.value.balanceFor(meera.id), 0);
    final summary = await TransactionRepository(database).getBalanceSummary();
    expect(summary.monthlyIncomePaise, 0);
    expect(summary.monthlyExpensesPaise, 40000);
    // Account balance: opening 10000.00 - 800.00 + 400.00.
    expect(summary.totalBalancePaise, 1000000 - 80000 + 40000);
  });

  test('someone else paid is a ledger-only note', () async {
    final arjun = await repo.addPerson('Arjun');
    await repo.addOwedByYou(
      personId: arjun.id,
      amountPaise: 80000,
      title: 'Movie',
      date: today,
    );
    expect(repo.ledger.value.balanceFor(arjun.id), -80000);
    expect(await allTransactions(), isEmpty);
  });

  test('deleting a linked transaction drops its split on reload', () async {
    final meera = await repo.addPerson('Meera');
    await repo.addSplitExpense(
      title: 'Dinner',
      totalPaise: 100000,
      accountId: accountId,
      categoryId: categoryId,
      date: today,
      shares: [
        const SplitShare(personId: null, paise: 50000),
        SplitShare(personId: meera.id, paise: 50000),
      ],
    );
    final lent = (await allTransactions()).firstWhere(
      (r) => r.source == kSplitLentSource,
    );
    await (database.delete(
      database.moneyTransactions,
    )..where((t) => t.id.equals(lent.id))).go();

    final reloaded = await repo.load();
    expect(reloaded.entries, isEmpty);
    expect(reloaded.people, hasLength(1));
  });

  test('deleteGroup removes entries and their transactions', () async {
    final meera = await repo.addPerson('Meera');
    await repo.addSplitExpense(
      title: 'Dinner',
      totalPaise: 100000,
      accountId: accountId,
      categoryId: null,
      date: today,
      shares: [
        const SplitShare(personId: null, paise: 50000),
        SplitShare(personId: meera.id, paise: 50000),
      ],
    );
    final groupId = repo.ledger.value.entries.single.groupId;
    await repo.deleteGroup(groupId);
    expect(repo.ledger.value.entries, isEmpty);
    expect(await allTransactions(), isEmpty);
  });

  test('rejects shares that do not add up', () async {
    final meera = await repo.addPerson('Meera');
    expect(
      () => repo.addSplitExpense(
        title: 'x',
        totalPaise: 1000,
        accountId: accountId,
        categoryId: null,
        date: today,
        shares: [
          const SplitShare(personId: null, paise: 100),
          SplitShare(personId: meera.id, paise: 100),
        ],
      ),
      throwsArgumentError,
    );
  });
}
