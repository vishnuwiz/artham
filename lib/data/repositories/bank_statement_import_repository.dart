import 'package:drift/drift.dart';

import '../app_database.dart';
import '../bank_statement_parser.dart';
import 'merchant_repository.dart';
import 'transaction_repository.dart';

class StatementImportResult {
  final int importedCount;
  final int duplicateCount;
  final int skippedCount;

  const StatementImportResult({
    required this.importedCount,
    required this.duplicateCount,
    required this.skippedCount,
  });
}

/// Saves a reviewed statement batch into the existing local transaction table.
class BankStatementImportRepository {
  final AppDatabase database;

  BankStatementImportRepository(this.database);

  Future<StatementImportResult> importTransactions({
    required int accountId,
    required List<StatementTransaction> transactions,
  }) async {
    final account = await (database.select(database.bankAccounts)
          ..where((row) => row.id.equals(accountId) & row.isActive.equals(true)))
        .getSingleOrNull();
    if (account == null) {
      throw StateError('Choose an active bank account before importing.');
    }

    await TransactionRepository(database).seedDefaultCategories();

    return database.transaction(() async {
      final existing = await (database.select(database.moneyTransactions)
            ..where((row) => row.accountId.equals(accountId)))
          .get();
      final knownKeys = <String>{
        for (final transaction in existing)
          if (transaction.transactionType == 'income' ||
              transaction.transactionType == 'expense')
            _duplicateKey(
              accountId: accountId,
              transactionType: transaction.transactionType,
              amountPaise: transaction.amountPaise,
              transactionDate: transaction.transactionDate,
              description: transaction.description,
              referenceNumber: transaction.referenceNumber,
            ),
      };

      final openingDate = DateTime(
        account.openingDate.year,
        account.openingDate.month,
        account.openingDate.day,
      );
      final seenInBatch = <String>{};
      var imported = 0;
      var duplicates = 0;
      var skipped = 0;
      final merchantRepository = MerchantRepository(database);

      for (final transaction in transactions) {
        if (transaction.amountPaise <= 0 ||
            (transaction.transactionType != 'income' &&
                transaction.transactionType != 'expense') ||
            transaction.description.trim().isEmpty) {
          skipped++;
          continue;
        }
        final date = DateTime(
          transaction.transactionDate.year,
          transaction.transactionDate.month,
          transaction.transactionDate.day,
        );
        if (date.isBefore(openingDate)) {
          skipped++;
          continue;
        }

        final key = _duplicateKey(
          accountId: accountId,
          transactionType: transaction.transactionType,
          amountPaise: transaction.amountPaise,
          transactionDate: date,
          description: transaction.description,
          referenceNumber: transaction.referenceNumber,
        );
        if (knownKeys.contains(key) || !seenInBatch.add(key)) {
          duplicates++;
          continue;
        }

        final merchantId = await merchantRepository.findOrCreateForDescription(
          description: transaction.description,
          transactionType: transaction.transactionType,
        );
        final fallbackCategoryName = transaction.transactionType == 'income'
            ? 'Other Income'
            : 'Other Expense';
        final fallbackCategory = await (database.select(database.categories)
              ..where((category) =>
                  category.name.equals(fallbackCategoryName) &
                  category.type.equals(transaction.transactionType)))
            .getSingleOrNull();
        final merchant = merchantId == null
            ? null
            : await (database.select(database.merchants)
                  ..where((row) => row.id.equals(merchantId)))
                .getSingleOrNull();
        final categoryId = merchant?.defaultCategoryId ?? fallbackCategory?.id;

        await database.into(database.moneyTransactions).insert(
              MoneyTransactionsCompanion.insert(
                accountId: accountId,
                categoryId: Value(categoryId),
                merchantId: Value(merchantId),
                amountPaise: transaction.amountPaise,
                transactionType: transaction.transactionType,
                transactionDate: date,
                description: Value(transaction.description.trim()),
                referenceNumber: Value(
                  transaction.referenceNumber?.trim().isEmpty == true
                      ? null
                      : transaction.referenceNumber?.trim(),
                ),
                source: const Value('statement'),
              ),
            );
        knownKeys.add(key);
        imported++;
      }

      return StatementImportResult(
        importedCount: imported,
        duplicateCount: duplicates,
        skippedCount: skipped,
      );
    });
  }

  static String _duplicateKey({
    required int accountId,
    required String transactionType,
    required int amountPaise,
    required DateTime transactionDate,
    required String? description,
    required String? referenceNumber,
  }) {
    final day =
        '${transactionDate.year.toString().padLeft(4, '0')}-'
        '${transactionDate.month.toString().padLeft(2, '0')}-'
        '${transactionDate.day.toString().padLeft(2, '0')}';
    final reference = referenceNumber?.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final identity = reference?.isNotEmpty == true
        ? 'ref:$reference'
        : 'desc:${(description ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    return '$accountId|$transactionType|$amountPaise|$day|$identity';
  }
}
