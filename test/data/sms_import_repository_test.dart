import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/sms_import_repository.dart';

void main() {
  late AppDatabase database;
  late SmsImportRepository repository;
  late int accountId;
  late int categoryId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SmsImportRepository(database);

    accountId = await database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: 'HDFC Bank',
            accountName: 'Savings',
            accountNumberLast4: const Value('1234'),
            openingBalancePaise: 100000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );

    categoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Food & Dining',
            type: 'expense',
            isSystem: const Value(true),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('imports an SMS transaction and records its fingerprint atomically',
      () async {
    final transactionId = await repository.importTransaction(
      fingerprint: 'sms-fingerprint-001',
      accountId: accountId,
      categoryId: categoryId,
      amountPaise: 125050,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 9),
      description: 'Swiggy',
      referenceNumber: '123456789012',
    );

    final transaction = await (database.select(database.moneyTransactions)
          ..where((row) => row.id.equals(transactionId)))
        .getSingle();
    final processedSms = await database.select(database.processedSms).get();

    expect(transaction.amountPaise, 125050);
    expect(transaction.transactionType, 'expense');
    expect(transaction.source, 'sms');
    expect(transaction.referenceNumber, '123456789012');
    expect(transaction.merchantId, isNotNull);
    final merchant = await (database.select(database.merchants)
          ..where((row) => row.id.equals(transaction.merchantId!)))
        .getSingle();
    expect(merchant.name, 'Swiggy');
    expect(merchant.defaultCategoryId, categoryId);
    expect(processedSms, hasLength(1));
    expect(processedSms.single.fingerprint, 'sms-fingerprint-001');
    expect(processedSms.single.isProcessed, isTrue);
  });

  test('rejects an SMS fingerprint that has already been imported', () async {
    final arguments = {
      'fingerprint': 'sms-fingerprint-duplicate',
      'accountId': accountId,
      'categoryId': categoryId,
      'amountPaise': 50000,
      'transactionType': 'expense',
      'transactionDate': DateTime(2026, 11, 9),
      'description': 'Fuel',
    };

    await repository.importTransaction(
      fingerprint: arguments['fingerprint'] as String,
      accountId: arguments['accountId'] as int,
      categoryId: arguments['categoryId'] as int,
      amountPaise: arguments['amountPaise'] as int,
      transactionType: arguments['transactionType'] as String,
      transactionDate: arguments['transactionDate'] as DateTime,
      description: arguments['description'] as String,
    );

    expect(
      () => repository.importTransaction(
        fingerprint: arguments['fingerprint'] as String,
        accountId: arguments['accountId'] as int,
        categoryId: arguments['categoryId'] as int,
        amountPaise: arguments['amountPaise'] as int,
        transactionType: arguments['transactionType'] as String,
        transactionDate: arguments['transactionDate'] as DateTime,
        description: arguments['description'] as String,
      ),
      throwsA(isA<DuplicateSmsImportException>()),
    );

    expect(await database.select(database.moneyTransactions).get(), hasLength(1));
    expect(await database.select(database.processedSms).get(), hasLength(1));
  });

  test('lists parsed pending automatic SMS imports without the original body', () async {
    const receivedAt = 1794250000000;
    const transactionDate = 1794240000000;

    await repository.ensurePendingImportsTable();
    await database.customInsert(
      '''
      INSERT INTO pending_sms_imports (
        fingerprint, sender, received_at, amount_paise, transaction_type,
        transaction_date, reference_number, description, suggested_category
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString('pending-fingerprint-001'),
        Variable.withString('VM-HDFCBK'),
        Variable.withInt(receivedAt),
        Variable.withInt(125050),
        Variable.withString('expense'),
        Variable.withInt(transactionDate),
        Variable.withString('UTR12345678'),
        Variable.withString('Swiggy'),
        Variable.withString('Food & Dining'),
      ],
    );

    final pending = await repository.getPendingImports();

    expect(pending, hasLength(1));
    expect(pending.single.sender, 'VM-HDFCBK');
    expect(pending.single.amountPaise, 125050);
    expect(pending.single.transactionType, 'expense');
    expect(pending.single.description, 'Swiggy');
    expect(pending.single.referenceNumber, 'UTR12345678');
    expect(
      pending.single.receivedAt,
      DateTime.fromMillisecondsSinceEpoch(receivedAt),
    );

    await repository.deletePendingImport(pending.single.id);
    expect(await repository.getPendingImports(), isEmpty);
  });

  test('normalizes message case and whitespace for duplicate fingerprints', () {
    expect(
      smsMessageFingerprint('  Rs 500 DEBITED  to Shop '),
      smsMessageFingerprint('rs 500 debited to shop'),
    );
  });
}
