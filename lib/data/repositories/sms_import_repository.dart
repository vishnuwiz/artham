import 'package:drift/drift.dart';

import '../app_database.dart';
import 'merchant_repository.dart';

class DuplicateSmsImportException implements Exception {
  const DuplicateSmsImportException();

  @override
  String toString() => 'This bank SMS has already been imported.';
}

/// Saves a user-reviewed SMS transaction and protects manual imports from
/// duplicates. This repository does not read or monitor the device inbox.
class SmsImportRepository {
  final AppDatabase database;

  SmsImportRepository(this.database);

  Future<bool> isDuplicate(String fingerprint) async {
    final existing = await (database.select(database.processedSms)
          ..where((sms) => sms.fingerprint.equals(fingerprint)))
        .getSingleOrNull();
    return existing != null;
  }

  /// Imports a user-reviewed SMS as a normal transaction and records its
  /// fingerprint in the same database transaction for duplicate protection.
  ///
  /// The original SMS body is not stored. Only its fingerprint and the
  /// structured transaction fields are retained.
  Future<int> importTransaction({
    required String fingerprint,
    required int accountId,
    required int categoryId,
    required int amountPaise,
    required String transactionType,
    required DateTime transactionDate,
    required String description,
    String? referenceNumber,
  }) async {
    if (fingerprint.trim().isEmpty) {
      throw ArgumentError('SMS fingerprint cannot be empty.');
    }
    if (amountPaise <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    if (transactionType != 'income' && transactionType != 'expense') {
      throw ArgumentError('Only income and expense SMS can be imported.');
    }

    return database.transaction(() async {
      final existing = await (database.select(database.processedSms)
            ..where((sms) => sms.fingerprint.equals(fingerprint)))
          .getSingleOrNull();
      if (existing != null) {
        throw const DuplicateSmsImportException();
      }

      await database.into(database.processedSms).insert(
            ProcessedSmsCompanion.insert(
              fingerprint: fingerprint,
              receivedAt: DateTime.now(),
              isProcessed: const Value(true),
            ),
          );

      final merchantId = await MerchantRepository(database)
          .findOrCreateForDescription(
        description: description,
        transactionType: transactionType,
        fallbackCategoryId: categoryId,
      );

      return database.into(database.moneyTransactions).insert(
            MoneyTransactionsCompanion.insert(
              accountId: accountId,
              categoryId: Value(categoryId),
              merchantId: Value(merchantId),
              amountPaise: amountPaise,
              transactionType: transactionType,
              transactionDate: transactionDate,
              description: Value(
                description.trim().isEmpty ? null : description.trim(),
              ),
              referenceNumber: Value(
                referenceNumber == null || referenceNumber.trim().isEmpty
                    ? null
                    : referenceNumber.trim(),
              ),
              source: const Value('sms'),
            ),
          );
    });
  }
}

/// Stable, non-cryptographic message fingerprint for local duplicate detection.
/// The raw SMS text is not written to the database.
String smsMessageFingerprint(String message) {
  final normalized = message.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
  var forward = 0x345678;
  var reverse = 0x123456;
  for (final unit in normalized.codeUnits) {
    forward = (forward * 31 + unit) & 0x7fffffff;
  }
  for (final unit in normalized.codeUnits.reversed) {
    reverse = (reverse * 37 + unit) & 0x7fffffff;
  }
  return '${forward.toRadixString(16).padLeft(8, '0')}'
      '${reverse.toRadixString(16).padLeft(8, '0')}';
}
