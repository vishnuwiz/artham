import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Builds local exports from Artham's Drift database.
///
/// Monetary values are kept as integer paise in JSON. The CSV additionally
/// includes a two-decimal INR column for spreadsheet use. Export files are
/// written to the operating system's temporary directory before sharing.
class DataExportService {
  final AppDatabase database;

  DataExportService(this.database);

  /// Creates a spreadsheet-friendly CSV containing all saved transactions.
  ///
  /// Account, category, merchant and transfer-destination names are resolved
  /// locally. Text fields are protected against spreadsheet formula injection.
  Future<String> buildTransactionsCsv() async {
    final accounts = await database.select(database.bankAccounts).get();
    final categories = await database.select(database.categories).get();
    final merchants = await database.select(database.merchants).get();
    final transactions = await (database.select(database.moneyTransactions)
          ..orderBy([
            (transaction) => OrderingTerm.desc(transaction.transactionDate),
            (transaction) => OrderingTerm.desc(transaction.createdAt),
          ]))
        .get();

    final accountsById = {
      for (final account in accounts) account.id: account,
    };
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final merchantsById = {
      for (final merchant in merchants) merchant.id: merchant,
    };

    final rows = <List<dynamic>>[
      [
        'Transaction ID',
        'Transaction Date',
        'Transaction Type',
        'Amount (INR)',
        'Amount (Paise)',
        'Account',
        'Account Last 4',
        'Transfer To Account',
        'Category',
        'Merchant',
        'Description',
        'Reference Number',
        'Notes',
        'Source',
        'Created At',
      ],
    ];

    for (final transaction in transactions) {
      final account = accountsById[transaction.accountId];
      final destination = transaction.transferToAccountId == null
          ? null
          : accountsById[transaction.transferToAccountId];
      final category = transaction.categoryId == null
          ? null
          : categoriesById[transaction.categoryId];
      final merchant = transaction.merchantId == null
          ? null
          : merchantsById[transaction.merchantId];

      rows.add([
        transaction.id,
        transaction.transactionDate.toIso8601String(),
        transaction.transactionType,
        _formatInr(transaction.amountPaise),
        transaction.amountPaise,
        _safeCsvText(
          account == null
              ? ''
              : bankAccountDisplayLabel(
                  account.bankName,
                  account.accountNumberLast4,
                ),
        ),
        _safeCsvText(account?.accountNumberLast4 ?? ''),
        _safeCsvText(
          destination == null
              ? ''
              : bankAccountDisplayLabel(
                  destination.bankName,
                  destination.accountNumberLast4,
                ),
        ),
        _safeCsvText(category?.name ?? ''),
        _safeCsvText(merchant?.name ?? ''),
        _safeCsvText(transaction.description ?? ''),
        _safeCsvText(transaction.referenceNumber ?? ''),
        _safeCsvText(transaction.notes ?? ''),
        _safeCsvText(transaction.source),
        transaction.createdAt.toIso8601String(),
      ]);
    }

    // A UTF-8 BOM is added when the file is written, not to this string,
    // so callers can decode the CSV without special handling.
    return Csv(lineDelimiter: '\r\n').encode(rows);
  }

  /// Creates a structured JSON export of all app database tables.
  ///
  /// Legacy pending SMS review rows are included when present so backups from
  /// earlier versions do not silently lose locally stored review data. Current
  /// versions do not create or consume those rows. Raw SMS bodies are never exported.
  Future<String> buildFullBackupJson() async {
    final accounts = await database.select(database.bankAccounts).get();
    final categories = await database.select(database.categories).get();
    final merchants = await database.select(database.merchants).get();
    final transactions =
        await database.select(database.moneyTransactions).get();
    final budgets = await database.select(database.budgets).get();
    final budgetTemplates =
        await database.select(database.budgetTemplates).get();
    final processedSms = await database.select(database.processedSms).get();
    final recurringSchedules =
        await database.select(database.recurringSchedules).get();
    final pendingSmsImports = await _readPendingSmsImports();

    final payload = <String, dynamic>{
      'format': 'artham_backup',
      'formatVersion': 1,
      'app': 'Artham',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'databaseSchemaVersion': database.schemaVersion,
      'currency': 'INR',
      'amountStorage': 'integer_paise',
      'data': {
        'bankAccounts': accounts
            .map(
              (account) => {
                'id': account.id,
                'bankName': account.bankName,
                'accountName': account.accountName,
                'accountNumberLast4': account.accountNumberLast4,
                'openingBalancePaise': account.openingBalancePaise,
                'openingDate': account.openingDate.toIso8601String(),
                'isActive': account.isActive,
                'createdAt': account.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'categories': categories
            .map(
              (category) => {
                'id': category.id,
                'name': category.name,
                'type': category.type,
                'iconKey': category.iconKey,
                'colorHex': category.colorHex,
                'isSystem': category.isSystem,
              },
            )
            .toList(),
        'merchants': merchants
            .map(
              (merchant) => {
                'id': merchant.id,
                'name': merchant.name,
                'defaultCategoryId': merchant.defaultCategoryId,
              },
            )
            .toList(),
        'moneyTransactions': transactions
            .map(
              (transaction) => {
                'id': transaction.id,
                'accountId': transaction.accountId,
                'transferToAccountId': transaction.transferToAccountId,
                'categoryId': transaction.categoryId,
                'merchantId': transaction.merchantId,
                'amountPaise': transaction.amountPaise,
                'transactionType': transaction.transactionType,
                'description': transaction.description,
                'referenceNumber': transaction.referenceNumber,
                'transactionDate':
                    transaction.transactionDate.toIso8601String(),
                'source': transaction.source,
                'notes': transaction.notes,
                'createdAt': transaction.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'budgets': budgets
            .map(
              (budget) => {
                'id': budget.id,
                'categoryId': budget.categoryId,
                'monthStart': budget.monthStart.toIso8601String(),
                'limitPaise': budget.limitPaise,
                'rolloverEnabled': budget.rolloverEnabled,
                'createdAt': budget.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'budgetTemplates': budgetTemplates
            .map(
              (template) => {
                'id': template.id,
                'categoryId': template.categoryId,
                'startMonth': template.startMonth.toIso8601String(),
                'limitPaise': template.limitPaise,
                'rolloverEnabled': template.rolloverEnabled,
                'isActive': template.isActive,
                'createdAt': template.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'processedSms': processedSms
            .map(
              (sms) => {
                'id': sms.id,
                'fingerprint': sms.fingerprint,
                'receivedAt': sms.receivedAt.toIso8601String(),
                'isProcessed': sms.isProcessed,
              },
            )
            .toList(),
        'recurringSchedules': recurringSchedules
            .map(
              (schedule) => {
                'id': schedule.id,
                'accountId': schedule.accountId,
                'categoryId': schedule.categoryId,
                'amountPaise': schedule.amountPaise,
                'transactionType': schedule.transactionType,
                'description': schedule.description,
                'frequency': schedule.frequency,
                'interval': schedule.interval,
                'startDate': schedule.startDate.toIso8601String(),
                'endDate': schedule.endDate?.toIso8601String(),
                'nextDueDate': schedule.nextDueDate.toIso8601String(),
                'isActive': schedule.isActive,
                'createdAt': schedule.createdAt.toIso8601String(),
              },
            )
            .toList(),
        'pendingSmsImports': pendingSmsImports,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Writes the transaction CSV to a temporary file for native sharing.
  Future<XFile> createTransactionsCsvFile() async {
    final csv = await buildTransactionsCsv();
    final contents = '\uFEFF$csv';
    return _writeExportFile(
      contents: contents,
      extension: 'csv',
      mimeType: 'text/csv',
    );
  }

  /// Writes the full JSON backup to a temporary file for native sharing.
  Future<XFile> createFullBackupFile() async {
    final json = await buildFullBackupJson();
    return _writeExportFile(
      contents: json,
      extension: 'json',
      mimeType: 'application/json',
    );
  }

  Future<XFile> _writeExportFile({
    required String contents,
    required String extension,
    required String mimeType,
  }) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      p.join(directory.path, 'artham_export_$timestamp.$extension'),
    );
    await file.writeAsBytes(
      utf8.encode(contents),
      flush: true,
    );
    return XFile(file.path, mimeType: mimeType);
  }

  Future<List<Map<String, dynamic>>> _readPendingSmsImports() async {
    final table = await database.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'pending_sms_imports'",
    ).getSingleOrNull();

    if (table == null) {
      return [];
    }

    final rows = await database.customSelect('''
      SELECT id, fingerprint, sender, received_at, amount_paise,
             transaction_type, transaction_date, reference_number,
             description, suggested_category
      FROM pending_sms_imports
      ORDER BY received_at DESC, id DESC
      ''').get();

    return rows
        .map(
          (row) => <String, dynamic>{
            'id': row.read<int>('id'),
            'fingerprint': row.read<String>('fingerprint'),
            'sender': row.read<String>('sender'),
            'receivedAtEpochMs': row.read<int>('received_at'),
            'amountPaise': row.read<int>('amount_paise'),
            'transactionType': row.read<String>('transaction_type'),
            'transactionDateEpochMs': row.read<int>('transaction_date'),
            'referenceNumber': row.readNullable<String>('reference_number'),
            'description': row.read<String>('description'),
            'suggestedCategory': row.read<String>('suggested_category'),
          },
        )
        .toList();
  }

  String _formatInr(int amountPaise) {
    final absolute = amountPaise.abs();
    final rupees = absolute ~/ 100;
    final paise = (absolute % 100).toString().padLeft(2, '0');
    final sign = amountPaise < 0 ? '-' : '';
    return '$sign$rupees.$paise';
  }

  String _safeCsvText(String value) {
    if (RegExp(r'^[\t\r ]*[=+\-@]').hasMatch(value)) {
      return "'$value";
    }
    return value;
  }
}
