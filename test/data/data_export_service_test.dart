import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/data_export_service.dart';

void main() {
  late AppDatabase database;
  late int accountId;
  late int secondAccountId;
  late int categoryId;
  late int merchantId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accountId = await database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'Federal Bank',
            accountName: 'Account 1255',
            accountNumberLast4: const Value('1255'),
            openingBalancePaise: 1000000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    secondAccountId = await database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'SBI',
            accountName: 'Account 7788',
            accountNumberLast4: const Value('7788'),
            openingBalancePaise: 500000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Food & Dining',
            type: 'expense',
          ),
        );
    merchantId = await database.into(database.merchants).insert(
          MerchantsCompanion.insert(
            name: 'Cafe Sample',
            defaultCategoryId: Value(categoryId),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('CSV contains transaction, merchant, account and transfer details',
      () async {
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            amountPaise: 12345,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 2, 9, 30),
            description: const Value('Cafe Sample, Fort Kochi'),
            referenceNumber: const Value('UTR123'),
            notes: const Value('Lunch'),
            source: const Value('sms'),
          ),
        );
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            transferToAccountId: Value(secondAccountId),
            amountPaise: 50000,
            transactionType: 'transfer',
            transactionDate: DateTime(2026, 11, 3, 10),
            description: const Value('Monthly savings'),
          ),
        );

    final file = await DataExportService(database).exportTransactionsCsv(
      exportedAt: DateTime(2026, 11, 10, 12, 30),
    );

    expect(file.fileName, contains('artham_transactions_all'));
    expect(file.mimeType, 'text/csv');
    expect(file.recordCount, 2);
    expect(file.contents, startsWith('\uFEFF'));
    expect(file.contents, contains('"12.45"'));
    expect(file.contents, contains('"Federal Bank"'));
    expect(file.contents, contains('"1255"'));
    expect(file.contents, contains('"Cafe Sample"'));
    expect(file.contents, contains('"UTR123"'));
    expect(file.contents, contains('"Monthly savings"'));
    expect(file.contents, contains('"SBI · •••• 7788"'));
  });

  test('CSV date range is inclusive and formula-like text is neutralised',
      () async {
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            amountPaise: 100,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 2, 9),
            description: const Value('=1+1'),
          ),
        );
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: 200,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 4, 23, 59),
            description: const Value('Late purchase'),
          ),
        );
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: 300,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 5),
            description: const Value('Outside range'),
          ),
        );

    final file = await DataExportService(database).exportTransactionsCsv(
      startDate: DateTime(2026, 11, 2),
      endDate: DateTime(2026, 11, 4),
    );

    expect(file.recordCount, 2);
    expect(file.contents, contains("\"'=1+1\""));
    expect(file.contents, contains('"Late purchase"'));
    expect(file.contents, isNot(contains('Outside range')));
  });

  test('CSV rejects an inverted date range', () async {
    expect(
      () => DataExportService(database).exportTransactionsCsv(
        startDate: DateTime(2026, 11, 5),
        endDate: DateTime(2026, 11, 1),
      ),
      throwsArgumentError,
    );
  });

  test('JSON backup exports all financial tables with exact paise values',
      () async {
    await database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            merchantId: Value(merchantId),
            amountPaise: 98765,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 2),
            description: const Value('Cafe Sample'),
          ),
        );
    await database.into(database.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: Value(categoryId),
            monthStart: DateTime(2026, 11, 1),
            limitPaise: 300000,
            rolloverEnabled: const Value(true),
          ),
        );
    await database.into(database.budgetTemplates).insert(
          BudgetTemplatesCompanion.insert(
            categoryId: Value(categoryId),
            startMonth: DateTime(2026, 11, 1),
            limitPaise: 400000,
            rolloverEnabled: const Value(true),
            isActive: const Value(true),
          ),
        );
    await database.into(database.recurringSchedules).insert(
          RecurringSchedulesCompanion.insert(
            accountId: accountId,
            categoryId: categoryId,
            amountPaise: 9900,
            transactionType: 'expense',
            frequency: 'monthly',
            startDate: DateTime(2026, 11, 1),
            nextDueDate: DateTime(2026, 12, 1),
          ),
        );

    final file = await DataExportService(database).exportFullFinancialBackup(
      exportedAt: DateTime(2026, 11, 10, 12),
    );
    final decoded = jsonDecode(file.contents) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final transaction =
        (tables['money_transactions'] as List).single as Map<String, dynamic>;

    expect(file.fileName, contains('artham_full_backup'));
    expect(file.mimeType, 'application/json');
    expect(decoded['format'], 'artham_financial_backup');
    expect(decoded['format_version'], 1);
    expect(decoded['database_schema_version'], database.schemaVersion);
    expect(transaction['amount_paise'], 98765);
    expect(tables['bank_accounts'], hasLength(2));
    expect(tables['categories'], hasLength(1));
    expect(tables['merchants'], hasLength(1));
    expect(tables['budgets'], hasLength(1));
    expect(tables['budget_templates'], hasLength(1));
    expect(tables['recurring_schedules'], hasLength(1));
    expect(tables, isNot(contains('processed_sms')));
    expect(decoded['excluded_data'], contains('Pending SMS review queue'));
  });
}
