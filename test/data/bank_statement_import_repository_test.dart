import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/bank_statement_parser.dart';
import 'package:artham/data/repositories/bank_statement_import_repository.dart';

void main() {
  group('BankStatementImportRepository', () {
    late AppDatabase database;
    late int accountId;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      accountId = await database.into(database.bankAccounts).insert(
        BankAccountsCompanion.insert(
          bankName: 'Federal Bank',
          accountName: 'Primary',
          accountNumberLast4: const Value('1255'),
          openingBalancePaise: 1000000,
          openingDate: DateTime(2026, 1, 1),
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('imports statement rows and skips duplicates in the same batch', () async {
      const transaction = StatementTransaction(
        transactionDate: DateTime(2026, 11, 10),
        description: 'Swiggy',
        amountPaise: 25000,
        transactionType: 'expense',
        referenceNumber: 'UPI-123456',
      );

      final result = await BankStatementImportRepository(database)
          .importTransactions(
        accountId: accountId,
        transactions: const [transaction, transaction],
      );

      expect(result.importedCount, 1);
      expect(result.duplicateCount, 1);
      expect(result.skippedCount, 0);

      final stored = await database.select(database.moneyTransactions).get();
      expect(stored, hasLength(1));
      expect(stored.single.source, 'statement');
      expect(stored.single.referenceNumber, 'UPI-123456');
      expect(stored.single.amountPaise, 25000);
      expect(stored.single.categoryId, isNotNull);
    });

    test('detects rows already imported for the account', () async {
      const transaction = StatementTransaction(
        transactionDate: DateTime(2026, 11, 10),
        description: 'Amazon',
        amountPaise: 99000,
        transactionType: 'expense',
        referenceNumber: 'REF-998877',
      );
      final repository = BankStatementImportRepository(database);

      await repository.importTransactions(
        accountId: accountId,
        transactions: const [transaction],
      );
      final second = await repository.importTransactions(
        accountId: accountId,
        transactions: const [transaction],
      );

      expect(second.importedCount, 0);
      expect(second.duplicateCount, 1);
    });

    test('skips transactions before account opening date and invalid entries', () async {
      final result = await BankStatementImportRepository(database)
          .importTransactions(
        accountId: accountId,
        transactions: const [
          StatementTransaction(
            transactionDate: DateTime(2025, 12, 31),
            description: 'Before account opened',
            amountPaise: 10000,
            transactionType: 'expense',
          ),
          StatementTransaction(
            transactionDate: DateTime(2026, 11, 10),
            description: 'Invalid zero',
            amountPaise: 0,
            transactionType: 'expense',
          ),
        ],
      );

      expect(result.importedCount, 0);
      expect(result.skippedCount, 2);
    });

    test('rejects inactive or missing destination accounts', () async {
      await expectLater(
        BankStatementImportRepository(database).importTransactions(
          accountId: -1,
          transactions: const [],
        ),
        throwsStateError,
      );
    });
  });
}
