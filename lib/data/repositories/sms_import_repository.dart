import 'package:drift/drift.dart';

import '../app_database.dart';

class DuplicateSmsImportException implements Exception {
  const DuplicateSmsImportException();

  @override
  String toString() => 'This bank SMS has already been imported.';
}

class PendingSmsImport {
  final int id;
  final String fingerprint;
  final String sender;
  final DateTime receivedAt;
  final int amountPaise;
  final String transactionType;
  final DateTime transactionDate;
  final String? referenceNumber;
  final String description;
  final String suggestedCategory;

  const PendingSmsImport({
    required this.id,
    required this.fingerprint,
    required this.sender,
    required this.receivedAt,
    required this.amountPaise,
    required this.transactionType,
    required this.transactionDate,
    required this.referenceNumber,
    required this.description,
    required this.suggestedCategory,
  });
}

class SmsImportRepository {
  final AppDatabase database;

  SmsImportRepository(this.database);

  Future<bool> isDuplicate(String fingerprint) async {
    final existing = await (database.select(database.processedSms)
          ..where((sms) => sms.fingerprint.equals(fingerprint)))
        .getSingleOrNull();
    return existing != null;
  }

  /// Creates a small auxiliary queue table used by the native Android SMS
  /// receiver for messages that could not be safely matched to an account.
  /// It stores parsed fields only, never the original SMS body.
  Future<void> ensurePendingImportsTable() {
    return database.customStatement('''
      CREATE TABLE IF NOT EXISTS pending_sms_imports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fingerprint TEXT NOT NULL UNIQUE,
        sender TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        amount_paise INTEGER NOT NULL,
        transaction_type TEXT NOT NULL,
        transaction_date INTEGER NOT NULL,
        reference_number TEXT,
        description TEXT NOT NULL,
        suggested_category TEXT NOT NULL
      )
    ''');
  }

  Future<List<PendingSmsImport>> getPendingImports() async {
    await ensurePendingImportsTable();
    final rows = await database.customSelect(
      '''
      SELECT id, fingerprint, sender, received_at, amount_paise,
             transaction_type, transaction_date, reference_number,
             description, suggested_category
      FROM pending_sms_imports
      ORDER BY received_at DESC, id DESC
      ''',
    ).get();

    final pending = <PendingSmsImport>[];
    for (final row in rows) {
      final fingerprint = row.read<String>('fingerprint');
      if (await isDuplicate(fingerprint)) {
        await deletePendingImport(row.read<int>('id'));
        continue;
      }
      pending.add(
        PendingSmsImport(
          id: row.read<int>('id'),
          fingerprint: fingerprint,
          sender: row.read<String>('sender'),
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('received_at'),
          ),
          amountPaise: row.read<int>('amount_paise'),
          transactionType: row.read<String>('transaction_type'),
          transactionDate: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('transaction_date'),
          ),
          referenceNumber: row.readNullable<String>('reference_number'),
          description: row.read<String>('description'),
          suggestedCategory: row.read<String>('suggested_category'),
        ),
      );
    }
    return pending;
  }

  Future<void> deletePendingImport(int id) {
    return database.customStatement(
      'DELETE FROM pending_sms_imports WHERE id = ?',
      variables: [Variable.withInt(id)],
    );
  }

  /// Imports a reviewed SMS as a normal transaction and records its
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

      return database.into(database.moneyTransactions).insert(
            MoneyTransactionsCompanion.insert(
              accountId: accountId,
              categoryId: Value(categoryId),
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
        RegExp(r'\\s+'),
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
