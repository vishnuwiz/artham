import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'app_database.dart';

/// Counts the records in a validated Artham JSON backup.
class ArthamBackupPreview {
  const ArthamBackupPreview({
    required this.exportedAt,
    required this.databaseSchemaVersion,
    required this.bankAccountCount,
    required this.categoryCount,
    required this.merchantCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.budgetTemplateCount,
    required this.processedSmsCount,
    required this.recurringScheduleCount,
    required this.legacyPendingSmsImportCount,
  });

  final DateTime exportedAt;
  final int databaseSchemaVersion;
  final int bankAccountCount;
  final int categoryCount;
  final int merchantCount;
  final int transactionCount;
  final int budgetCount;
  final int budgetTemplateCount;
  final int processedSmsCount;
  final int recurringScheduleCount;

  /// Rows from an older SMS review queue. The current schema no longer has
  /// this table, so these rows are reported rather than silently discarded.
  final int legacyPendingSmsImportCount;
}

/// Validates and restores a complete local Artham backup.
///
/// The restore replaces the current local records. Parsing and validation are
/// completed before the database transaction begins. All deletes and inserts
/// then run in one transaction, so a database error rolls the restore back.
class DataImportService {
  DataImportService(this.database);

  final AppDatabase database;

  ArthamBackupPreview inspectFullBackupJson(String contents) {
    return _parseBackup(contents).preview;
  }

  Future<ArthamBackupPreview> restoreFullBackupJson(String contents) async {
    final backup = _parseBackup(contents);

    await database.transaction(() async {
      // Delete children before parents to respect foreign-key relationships.
      await database.delete(database.recurringSchedules).go();
      await database.delete(database.moneyTransactions).go();
      await database.delete(database.budgets).go();
      await database.delete(database.budgetTemplates).go();
      await database.delete(database.merchants).go();
      await database.delete(database.processedSms).go();
      await database.delete(database.categories).go();
      await database.delete(database.bankAccounts).go();

      // Insert parents before children, preserving original record IDs.
      await database.batch((batch) {
        if (backup.bankAccounts.isNotEmpty) {
          batch.insertAll(database.bankAccounts, backup.bankAccounts);
        }
        if (backup.categories.isNotEmpty) {
          batch.insertAll(database.categories, backup.categories);
        }
        if (backup.merchants.isNotEmpty) {
          batch.insertAll(database.merchants, backup.merchants);
        }
        if (backup.transactions.isNotEmpty) {
          batch.insertAll(database.moneyTransactions, backup.transactions);
        }
        if (backup.budgets.isNotEmpty) {
          batch.insertAll(database.budgets, backup.budgets);
        }
        if (backup.budgetTemplates.isNotEmpty) {
          batch.insertAll(database.budgetTemplates, backup.budgetTemplates);
        }
        if (backup.processedSms.isNotEmpty) {
          batch.insertAll(database.processedSms, backup.processedSms);
        }
        if (backup.recurringSchedules.isNotEmpty) {
          batch.insertAll(
            database.recurringSchedules,
            backup.recurringSchedules,
          );
        }
      });
    });

    return backup.preview;
  }

  _ParsedBackup _parseBackup(String contents) {
    late final dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('The selected file is not valid JSON: $error');
    }

    if (decoded is! Map) {
      throw const FormatException('The selected file is not an Artham backup.');
    }

    final root = Map<String, dynamic>.from(decoded);
    if (root['format'] != 'artham_backup' || root['app'] != 'Artham') {
      throw const FormatException('This file is not a valid Artham backup.');
    }

    if (_requiredInt(root, 'formatVersion') != 1) {
      throw const FormatException(
        'This backup format version is not supported by this version of Artham.',
      );
    }

    final schemaVersion = _requiredInt(root, 'databaseSchemaVersion');
    if (schemaVersion < 1 || schemaVersion > database.schemaVersion) {
      throw FormatException(
        'This backup uses database schema version $schemaVersion, which this '
        'version of Artham cannot restore.',
      );
    }

    if (root['currency'] != 'INR' || root['amountStorage'] != 'integer_paise') {
      throw const FormatException(
        'The backup currency or amount format is not supported.',
      );
    }

    final exportedAt = _requiredDate(root, 'exportedAt');
    final dataValue = root['data'];
    if (dataValue is! Map) {
      throw const FormatException('The backup data section is missing.');
    }
    final data = Map<String, dynamic>.from(dataValue);

    final bankAccounts = _parseRows(data, 'bankAccounts', _parseBankAccount);
    final categories = _parseRows(data, 'categories', _parseCategory);
    final merchants = _parseRows(data, 'merchants', _parseMerchant);
    final transactions = _parseRows(
      data,
      'moneyTransactions',
      _parseTransaction,
    );
    final budgets = _parseRows(data, 'budgets', _parseBudget);
    final budgetTemplates = _parseRows(
      data,
      'budgetTemplates',
      _parseBudgetTemplate,
    );
    final processedSms = _parseRows(data, 'processedSms', _parseProcessedSms);
    final recurringSchedules = _parseRows(
      data,
      'recurringSchedules',
      _parseRecurringSchedule,
    );
    final pendingSmsImports = _parseLegacyPendingSmsImports(
      data['pendingSmsImports'],
    );

    return _ParsedBackup(
      bankAccounts: bankAccounts,
      categories: categories,
      merchants: merchants,
      transactions: transactions,
      budgets: budgets,
      budgetTemplates: budgetTemplates,
      processedSms: processedSms,
      recurringSchedules: recurringSchedules,
      preview: ArthamBackupPreview(
        exportedAt: exportedAt,
        databaseSchemaVersion: schemaVersion,
        bankAccountCount: bankAccounts.length,
        categoryCount: categories.length,
        merchantCount: merchants.length,
        transactionCount: transactions.length,
        budgetCount: budgets.length,
        budgetTemplateCount: budgetTemplates.length,
        processedSmsCount: processedSms.length,
        recurringScheduleCount: recurringSchedules.length,
        legacyPendingSmsImportCount: pendingSmsImports,
      ),
    );
  }

  List<T> _parseRows<T>(
    Map<String, dynamic> data,
    String key,
    T Function(Map<String, dynamic>) parser,
  ) {
    final value = data[key];
    if (value is! List) {
      throw FormatException('The backup is missing the $key list.');
    }

    final parsed = <T>[];
    for (var index = 0; index < value.length; index++) {
      final row = value[index];
      if (row is! Map) {
        throw FormatException('The $key item at position $index is invalid.');
      }
      try {
        parsed.add(parser(Map<String, dynamic>.from(row)));
      } catch (error) {
        throw FormatException(
          'The $key item at position $index is invalid: $error',
        );
      }
    }
    return parsed;
  }

  BankAccountsCompanion _parseBankAccount(Map<String, dynamic> row) {
    return BankAccountsCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      bankName: _requiredString(row, 'bankName'),
      accountName: _requiredString(row, 'accountName'),
      accountNumberLast4: Value(_optionalString(row, 'accountNumberLast4')),
      openingBalancePaise: _requiredInt(row, 'openingBalancePaise'),
      openingDate: _requiredDate(row, 'openingDate'),
      isActive: Value(_requiredBool(row, 'isActive')),
      createdAt: Value(_requiredDate(row, 'createdAt')),
    );
  }

  CategoriesCompanion _parseCategory(Map<String, dynamic> row) {
    return CategoriesCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      name: _requiredString(row, 'name'),
      type: _requiredString(row, 'type'),
      iconKey: Value(_optionalString(row, 'iconKey')),
      colorHex: Value(_optionalString(row, 'colorHex')),
      isSystem: Value(_requiredBool(row, 'isSystem')),
      // Schema v5 added these fields. Older backups omit them, so use the
      // database defaults when restoring a schema v4 (or earlier) backup.
      seedKey: Value(_optionalString(row, 'seedKey')),
      isArchived: Value(
        row.containsKey('isArchived')
            ? _requiredBool(row, 'isArchived')
            : false,
      ),
    );
  }

  MerchantsCompanion _parseMerchant(Map<String, dynamic> row) {
    return MerchantsCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      name: _requiredString(row, 'name'),
      defaultCategoryId: Value(_optionalInt(row, 'defaultCategoryId')),
    );
  }

  MoneyTransactionsCompanion _parseTransaction(Map<String, dynamic> row) {
    return MoneyTransactionsCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      accountId: _requiredId(row, 'accountId'),
      transferToAccountId: Value(_optionalInt(row, 'transferToAccountId')),
      categoryId: Value(_optionalInt(row, 'categoryId')),
      merchantId: Value(_optionalInt(row, 'merchantId')),
      amountPaise: _requiredInt(row, 'amountPaise'),
      transactionType: _requiredString(row, 'transactionType'),
      description: Value(_optionalString(row, 'description')),
      referenceNumber: Value(_optionalString(row, 'referenceNumber')),
      transactionDate: _requiredDate(row, 'transactionDate'),
      source: Value(_requiredString(row, 'source')),
      notes: Value(_optionalString(row, 'notes')),
      createdAt: Value(_requiredDate(row, 'createdAt')),
    );
  }

  BudgetsCompanion _parseBudget(Map<String, dynamic> row) {
    return BudgetsCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      categoryId: Value(_optionalInt(row, 'categoryId')),
      monthStart: _requiredDate(row, 'monthStart'),
      limitPaise: _requiredInt(row, 'limitPaise'),
      rolloverEnabled: Value(_requiredBool(row, 'rolloverEnabled')),
      createdAt: Value(_requiredDate(row, 'createdAt')),
    );
  }

  BudgetTemplatesCompanion _parseBudgetTemplate(Map<String, dynamic> row) {
    return BudgetTemplatesCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      categoryId: Value(_optionalInt(row, 'categoryId')),
      startMonth: _requiredDate(row, 'startMonth'),
      limitPaise: _requiredInt(row, 'limitPaise'),
      rolloverEnabled: Value(_requiredBool(row, 'rolloverEnabled')),
      isActive: Value(_requiredBool(row, 'isActive')),
      createdAt: Value(_requiredDate(row, 'createdAt')),
    );
  }

  ProcessedSmsCompanion _parseProcessedSms(Map<String, dynamic> row) {
    return ProcessedSmsCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      fingerprint: _requiredString(row, 'fingerprint'),
      receivedAt: _requiredDate(row, 'receivedAt'),
      isProcessed: Value(_requiredBool(row, 'isProcessed')),
    );
  }

  RecurringSchedulesCompanion _parseRecurringSchedule(
    Map<String, dynamic> row,
  ) {
    return RecurringSchedulesCompanion.insert(
      id: Value(_requiredId(row, 'id')),
      accountId: _requiredId(row, 'accountId'),
      categoryId: _requiredId(row, 'categoryId'),
      amountPaise: _requiredInt(row, 'amountPaise'),
      transactionType: _requiredString(row, 'transactionType'),
      description: Value(_optionalString(row, 'description')),
      frequency: _requiredString(row, 'frequency'),
      interval: Value(_requiredInt(row, 'interval')),
      startDate: _requiredDate(row, 'startDate'),
      endDate: Value(_optionalDate(row, 'endDate')),
      nextDueDate: _requiredDate(row, 'nextDueDate'),
      isActive: Value(_requiredBool(row, 'isActive')),
      createdAt: Value(_requiredDate(row, 'createdAt')),
    );
  }

  int _parseLegacyPendingSmsImports(dynamic value) {
    if (value == null) return 0;
    if (value is! List) {
      throw const FormatException(
        'The backup pendingSmsImports section is invalid.',
      );
    }
    return value.length;
  }

  int _requiredId(Map<String, dynamic> row, String key) {
    final value = _requiredInt(row, key);
    if (value <= 0) {
      throw FormatException('$key must be a positive record ID.');
    }
    return value;
  }

  int _requiredInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int) {
      throw FormatException('$key must be an integer.');
    }
    return value;
  }

  int? _optionalInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('$key must be an integer or null.');
    }
    return value;
  }

  String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key must be a string or null.');
    }
    return value;
  }

  bool _requiredBool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw FormatException('$key must be true or false.');
    }
    return value;
  }

  DateTime _requiredDate(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String) {
      throw FormatException('$key must be an ISO 8601 date.');
    }
    return DateTime.parse(value);
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$key must be an ISO 8601 date or null.');
    }
    return DateTime.parse(value);
  }
}

class _ParsedBackup {
  const _ParsedBackup({
    required this.bankAccounts,
    required this.categories,
    required this.merchants,
    required this.transactions,
    required this.budgets,
    required this.budgetTemplates,
    required this.processedSms,
    required this.recurringSchedules,
    required this.preview,
  });

  final List<BankAccountsCompanion> bankAccounts;
  final List<CategoriesCompanion> categories;
  final List<MerchantsCompanion> merchants;
  final List<MoneyTransactionsCompanion> transactions;
  final List<BudgetsCompanion> budgets;
  final List<BudgetTemplatesCompanion> budgetTemplates;
  final List<ProcessedSmsCompanion> processedSms;
  final List<RecurringSchedulesCompanion> recurringSchedules;
  final ArthamBackupPreview preview;
}
