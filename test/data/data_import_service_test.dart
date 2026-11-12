import 'dart:convert';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/data_export_service.dart';
import 'package:artham/data/data_import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase sourceDatabase;
  late AppDatabase targetDatabase;

  setUp(() {
    sourceDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    targetDatabase = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await sourceDatabase.close();
    await targetDatabase.close();
  });

  test('restores all supported records and replaces existing local data',
      () async {
    final accountId = await sourceDatabase.into(sourceDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Federal Bank',
            accountName: 'Primary account',
            accountNumberLast4: const Value('1255'),
            openingBalancePaise: 250000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    final destinationAccountId = await sourceDatabase.into(sourceDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'HDFC Bank',
            accountName: 'Savings account',
            accountNumberLast4: const Value('7788'),
            openingBalancePaise: 100000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    final categoryId = await sourceDatabase.into(sourceDatabase.categories).insert(
          CategoriesCompanion.insert(
            name: 'Restaurants',
            type: 'expense',
            iconKey: const Value('restaurant'),
            colorHex: const Value('#FFD3A0'),
            isSystem: const Value(true),
            seedKey: const Value('expense.restaurants'),
            isArchived: const Value(true),
          ),
        );
    await sourceDatabase.into(sourceDatabase.categories).insert(
          CategoriesCompanion.insert(
            name: 'Photography',
            type: 'expense',
            iconKey: const Value('devices'),
            colorHex: const Value('#8CBEFF'),
          ),
        );
    final merchantId = await sourceDatabase.into(sourceDatabase.merchants).insert(
          MerchantsCompanion.insert(
            name: 'Cafe Kochi',
            defaultCategoryId: Value(categoryId),
          ),
        );

    await sourceDatabase.into(sourceDatabase.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            amountPaise: 12500,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 10, 9, 30),
            description: const Value('Coffee'),
            source: const Value('manual'),
          ),
        );
    await sourceDatabase.into(sourceDatabase.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            transferToAccountId: Value(destinationAccountId),
            amountPaise: 25000,
            transactionType: 'transfer',
            transactionDate: DateTime(2026, 11, 10, 10, 0),
            description: const Value('Move to savings'),
            source: const Value('manual'),
          ),
        );
    await sourceDatabase.into(sourceDatabase.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            monthStart: DateTime(2026, 11, 1),
            limitPaise: 500000,
            rolloverEnabled: const Value(true),
          ),
        );
    await sourceDatabase.into(sourceDatabase.budgetTemplates).insert(
          BudgetTemplatesCompanion.insert(
            categoryId: Value(categoryId),
            startMonth: DateTime(2026, 11, 1),
            limitPaise: 450000,
            rolloverEnabled: const Value(false),
            isActive: const Value(true),
          ),
        );
    await sourceDatabase.into(sourceDatabase.processedSms).insert(
          ProcessedSmsCompanion.insert(
            fingerprint: 'sms-fingerprint-1',
            receivedAt: DateTime(2026, 11, 10, 9, 31),
            isProcessed: const Value(true),
          ),
        );
    await sourceDatabase.into(sourceDatabase.recurringSchedules).insert(
          RecurringSchedulesCompanion.insert(
            accountId: accountId,
            categoryId: categoryId,
            amountPaise: 75000,
            transactionType: 'expense',
            description: const Value('Monthly rent'),
            frequency: 'monthly',
            interval: const Value(1),
            startDate: DateTime(2026, 1, 1),
            endDate: const Value(null),
            nextDueDate: DateTime(2026, 12, 1),
            isActive: const Value(true),
          ),
        );

    await targetDatabase.into(targetDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Old Bank',
            accountName: 'Old local account',
            openingBalancePaise: 100,
            openingDate: DateTime(2025, 1, 1),
          ),
        );

    final backup = await DataExportService(
      sourceDatabase,
    ).buildFullBackupJson();
    final importService = DataImportService(targetDatabase);
    final preview = importService.inspectFullBackupJson(backup);

    expect(preview.bankAccountCount, 2);
    expect(preview.categoryCount, 2);
    expect(preview.merchantCount, 1);
    expect(preview.transactionCount, 2);
    expect(preview.budgetCount, 1);
    expect(preview.budgetTemplateCount, 1);
    expect(preview.processedSmsCount, 1);
    expect(preview.recurringScheduleCount, 1);

    await importService.restoreFullBackupJson(backup);

    final accounts = await targetDatabase.select(targetDatabase.bankAccounts).get();
    final categories = await targetDatabase.select(targetDatabase.categories).get();
    final merchants = await targetDatabase.select(targetDatabase.merchants).get();
    final transactions = await targetDatabase.select(targetDatabase.moneyTransactions).get();
    final budgets = await targetDatabase.select(targetDatabase.budgets).get();
    final budgetTemplates = await targetDatabase.select(targetDatabase.budgetTemplates).get();
    final processedSms = await targetDatabase.select(targetDatabase.processedSms).get();
    final schedules = await targetDatabase.select(targetDatabase.recurringSchedules).get();

    expect(accounts, hasLength(2));
    expect(accounts.map((account) => account.bankName),
        containsAll(['Federal Bank', 'HDFC Bank']));
    expect(accounts.singleWhere((account) => account.bankName == 'Federal Bank').id,
        accountId);
    expect(accounts.singleWhere((account) => account.bankName == 'HDFC Bank').id,
        destinationAccountId);
    final archivedBuiltIn = categories.singleWhere(
      (category) => category.name == 'Restaurants',
    );
    expect(archivedBuiltIn.seedKey, 'expense.restaurants');
    expect(archivedBuiltIn.isArchived, isTrue);
    expect(archivedBuiltIn.isSystem, isTrue);
    expect(archivedBuiltIn.iconKey, 'restaurant');
    expect(archivedBuiltIn.colorHex, '#FFD3A0');
    final customCategory = categories.singleWhere(
      (category) => category.name == 'Photography',
    );
    expect(customCategory.seedKey, isNull);
    expect(customCategory.isArchived, isFalse);
    expect(customCategory.iconKey, 'devices');
    expect(customCategory.colorHex, '#8CBEFF');
    expect(merchants.single.name, 'Cafe Kochi');
    expect(merchants.single.defaultCategoryId, categoryId);
    expect(transactions, hasLength(2));
    final expense = transactions.singleWhere(
      (transaction) => transaction.transactionType == 'expense',
    );
    final transfer = transactions.singleWhere(
      (transaction) => transaction.transactionType == 'transfer',
    );
    expect(expense.amountPaise, 12500);
    expect(expense.accountId, accountId);
    expect(expense.categoryId, categoryId);
    expect(expense.merchantId, merchantId);
    expect(transfer.amountPaise, 25000);
    expect(transfer.accountId, accountId);
    expect(transfer.transferToAccountId, destinationAccountId);
    expect(transfer.categoryId, isNull);
    expect(budgets.single.limitPaise, 500000);
    expect(budgetTemplates.single.limitPaise, 450000);
    expect(processedSms.single.fingerprint, 'sms-fingerprint-1');
    expect(schedules.single.description, 'Monthly rent');
  });

  test('rejects an unsupported backup without changing local records',
      () async {
    await targetDatabase.into(targetDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Keep This Bank',
            accountName: 'Existing account',
            openingBalancePaise: 900,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    final importService = DataImportService(targetDatabase);

    expect(
      () => importService.inspectFullBackupJson(
        jsonEncode({'format': 'not_artham'}),
      ),
      throwsFormatException,
    );

    final accounts = await targetDatabase.select(targetDatabase.bankAccounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.bankName, 'Keep This Bank');
  });

  test('rolls back the replacement if a database insert fails', () async {
    final existingAccountId = await targetDatabase.into(targetDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Keep This Bank',
            accountName: 'Existing account',
            openingBalancePaise: 900,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    await sourceDatabase.into(sourceDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Backup Bank',
            accountName: 'Backup account',
            openingBalancePaise: 1000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    final backup = jsonDecode(
      await DataExportService(sourceDatabase).buildFullBackupJson(),
    ) as Map<String, dynamic>;
    final data = backup['data'] as Map<String, dynamic>;
    final accounts = data['bankAccounts'] as List<dynamic>;
    accounts.add(Map<String, dynamic>.from(accounts.single as Map));
    (accounts.last as Map<String, dynamic>)['bankName'] = 'Duplicate ID';

    expect(
      DataImportService(targetDatabase).restoreFullBackupJson(
        jsonEncode(backup),
      ),
      throwsA(anything),
    );

    final restoredAccounts =
        await targetDatabase.select(targetDatabase.bankAccounts).get();
    expect(restoredAccounts, hasLength(1));
    expect(restoredAccounts.single.bankName, 'Keep This Bank');
    expect(restoredAccounts.single.id, existingAccountId);
  });

  test('restores legacy categories without schema v5 fields using defaults',
      () async {
    final backup = jsonDecode(
      await DataExportService(sourceDatabase).buildFullBackupJson(),
    ) as Map<String, dynamic>;
    backup['databaseSchemaVersion'] = 4;
    final data = backup['data'] as Map<String, dynamic>;
    final categories = data['categories'] as List<dynamic>;
    categories.add({
      'id': 1,
      'name': 'Legacy Food',
      'type': 'expense',
      'iconKey': null,
      'colorHex': null,
      'isSystem': true,
    });

    // Keep only the legacy category fixture in this minimal legacy backup.
    data['bankAccounts'] = <dynamic>[];
    data['merchants'] = <dynamic>[];
    data['moneyTransactions'] = <dynamic>[];
    data['budgets'] = <dynamic>[];
    data['budgetTemplates'] = <dynamic>[];
    data['processedSms'] = <dynamic>[];
    data['recurringSchedules'] = <dynamic>[];
    data['categories'] = [categories.last];

    await DataImportService(targetDatabase).restoreFullBackupJson(
      jsonEncode(backup),
    );

    final restored = await targetDatabase.select(targetDatabase.categories).get();
    expect(restored, hasLength(1));
    expect(restored.single.name, 'Legacy Food');
    expect(restored.single.seedKey, isNull);
    expect(restored.single.isArchived, isFalse);
  });

  test('rejects a backup created by a newer database schema', () async {
    final backup = jsonDecode(
      await DataExportService(sourceDatabase).buildFullBackupJson(),
    ) as Map<String, dynamic>;
    backup['databaseSchemaVersion'] = targetDatabase.schemaVersion + 1;

    expect(
      () => DataImportService(targetDatabase).inspectFullBackupJson(
        jsonEncode(backup),
      ),
      throwsFormatException,
    );
  });
}
