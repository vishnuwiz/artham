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
    final categoryId = await sourceDatabase.into(sourceDatabase.categories).insert(
          CategoriesCompanion.insert(
            name: 'Food & Dining',
            type: 'expense',
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

    expect(preview.bankAccountCount, 1);
    expect(preview.categoryCount, 1);
    expect(preview.merchantCount, 1);
    expect(preview.transactionCount, 1);
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

    expect(accounts, hasLength(1));
    expect(accounts.single.bankName, 'Federal Bank');
    expect(accounts.single.id, accountId);
    expect(categories.single.name, 'Food & Dining');
    expect(merchants.single.name, 'Cafe Kochi');
    expect(merchants.single.defaultCategoryId, categoryId);
    expect(transactions.single.amountPaise, 12500);
    expect(transactions.single.accountId, accountId);
    expect(transactions.single.categoryId, categoryId);
    expect(transactions.single.merchantId, merchantId);
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
    await targetDatabase.into(targetDatabase.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Keep This Bank',
            accountName: 'Existing account',
            openingBalancePaise: 900,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    final accountId = await sourceDatabase.into(sourceDatabase.bankAccounts).insert(
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
    expect(restoredAccounts.single.id, isNot(accountId));
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
