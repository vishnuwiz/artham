import 'dart:convert';
import 'dart:io';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/data_export_service.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DataExportService exportService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    exportService = DataExportService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('CSV export contains headers when there are no transactions', () async {
    final csv = await exportService.buildTransactionsCsv();
    final rows = Csv().decode(csv);

    expect(rows, hasLength(1));
    expect(rows.first.first, 'Transaction ID');
    expect(rows.first, contains('Amount (INR)'));
    expect(rows.first, contains('Transfer To Account'));
  });

  test(
    'CSV export resolves account and category and quotes descriptions',
    () async {
      final accountId = await database
          .into(database.bankAccounts)
          .insert(
            BankAccountsCompanion.insert(
              bankName: 'Federal Bank',
              accountName: 'Account 1255',
              accountNumberLast4: const Value('1255'),
              openingBalancePaise: 100000,
              openingDate: DateTime(2026, 1, 1),
            ),
          );
      final categoryId = await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(name: 'Restaurants', type: 'expense'),
          );

      await database
          .into(database.moneyTransactions)
          .insert(
            MoneyTransactionsCompanion.insert(
              accountId: accountId,
              categoryId: Value(categoryId),
              amountPaise: 12500,
              transactionType: 'expense',
              transactionDate: DateTime(2026, 11, 10, 9, 30),
              description: const Value('Cafe, Kochi'),
            ),
          );

      final rows = Csv().decode(await exportService.buildTransactionsCsv());

      expect(rows, hasLength(2));
      expect(rows[1][3], '125.00');
      expect(rows[1][5], 'Federal Bank · •••• 1255');
      expect(rows[1][8], 'Restaurants');
      expect(rows[1][10], 'Cafe, Kochi');
    },
  );

  test('creates a persistent local safety backup file', () async {
    final documentsDirectory = await Directory.systemTemp.createTemp(
      'artham-safety-backup-test-',
    );
    addTearDown(() async {
      await documentsDirectory.delete(recursive: true);
    });

    final service = DataExportService(
      database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );

    final file = await service.createLocalSafetyBackupFile();

    expect(await file.exists(), isTrue);
    expect(file.path, contains('restore_safety_backups'));
    expect(file.path, endsWith('.json'));

    final backup =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(backup['format'], 'artham_backup');
    expect(backup['app'], 'Artham');
    expect(backup['formatVersion'], 1);
  });

  test('JSON backup contains every database table and paise amounts', () async {
    final accountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'Federal Bank',
            accountName: 'Account 1255',
            accountNumberLast4: const Value('1255'),
            openingBalancePaise: 100000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    final categoryId = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(name: 'Restaurants', type: 'expense'),
        );

    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: 12500,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 10, 9, 30),
          ),
        );

    final backup = jsonDecode(
      await exportService.buildFullBackupJson(),
    ) as Map<String, dynamic>;
    final data = backup['data'] as Map<String, dynamic>;
    final transactions = data['moneyTransactions'] as List<dynamic>;
    final exportedTransaction = transactions.single as Map<String, dynamic>;

    expect(backup['format'], 'artham_backup');
    expect(backup['formatVersion'], 1);
    expect(
      data.keys,
      containsAll([
        'bankAccounts',
        'categories',
        'merchants',
        'moneyTransactions',
        'budgets',
        'budgetTemplates',
        'processedSms',
        'recurringSchedules',
        'pendingSmsImports',
      ]),
    );
    expect(exportedTransaction['amountPaise'], 12500);
    expect(exportedTransaction['transactionType'], 'expense');
  });
}
