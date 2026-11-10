import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

class DataExportFile {
  final String fileName;
  final String mimeType;
  final String contents;
  final int recordCount;

  const DataExportFile({
    required this.fileName,
    required this.mimeType,
    required this.contents,
    required this.recordCount,
  });

  List<int> get bytes => utf8.encode(contents);
}

/// Builds exports from the local Drift database without network access or
/// database writes.
class DataExportService {
  final AppDatabase database;

  const DataExportService(this.database);

  Future<DataExportFile> exportTransactionsCsv({
    DateTime? startDate,
    DateTime? endDate,
    DateTime? exportedAt,
  }) async {
    final start = startDate == null ? null : _dateOnly(startDate);
    final end = endDate == null ? null : _dateOnly(endDate);

    if (start != null && end != null && start.isAfter(end)) {
      throw ArgumentError('Start date must not be after end date.');
    }

    final query = database.select(database.moneyTransactions)
      ..orderBy([
        (transaction) => OrderingTerm.asc(transaction.transactionDate),
        (transaction) => OrderingTerm.asc(transaction.id),
      ]);

    if (start != null) {
      query.where(
        (transaction) =>
            transaction.transactionDate.isBiggerOrEqualValue(start),
      );
    }
    if (end != null) {
      final endExclusive = DateTime(end.year, end.month, end.day + 1);
      query.where(
        (transaction) =>
            transaction.transactionDate.isSmallerThanValue(endExclusive),
      );
    }

    final transactions = await query.get();
    final accounts = await database.select(database.bankAccounts).get();
    final categories = await database.select(database.categories).get();
    final merchants = await database.select(database.merchants).get();

    final accountsById = {
      for (final account in accounts) account.id: account,
    };
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final merchantsById = {
      for (final merchant in merchants) merchant.id: merchant,
    };

    final rows = <List<Object?>>[
      [
        'Transaction ID',
        'Transaction Date',
        'Transaction Type',
        'Amount (INR)',
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
      final transferAccount = transaction.transferToAccountId == null
          ? null
          : accountsById[transaction.transferToAccountId!];
      final category = transaction.categoryId == null
          ? null
          : categoriesById[transaction.categoryId!];
      final merchant = transaction.merchantId == null
          ? null
          : merchantsById[transaction.merchantId!];

      rows.add([
        transaction.id,
        transaction.transactionDate.toIso8601String(),
        transaction.transactionType,
        _formatPaise(transaction.amountPaise),
        account?.bankName ?? '',
        account?.accountNumberLast4 ?? '',
        transferAccount == null
            ? ''
            : bankAccountDisplayLabel(
                transferAccount.bankName,
                transferAccount.accountNumberLast4,
              ),
        category?.name ?? '',
        merchant?.name ?? '',
        transaction.description ?? '',
        transaction.referenceNumber ?? '',
        transaction.notes ?? '',
        transaction.source,
        transaction.createdAt.toIso8601String(),
      ]);
    }

    final csv = rows.map(_csvLine).join('\r\n');
    final timestamp = exportedAt ?? DateTime.now();
    final dateSuffix = start == null && end == null
        ? 'all'
        : '${start == null ? 'beginning' : _dateStamp(start)}'
            '_to_${end == null ? 'latest' : _dateStamp(end)}';

    return DataExportFile(
      fileName: 'artham_transactions_${dateSuffix}_${_timeStamp(timestamp)}.csv',
      mimeType: 'text/csv',
      contents: '\uFEFF${csv}',
      recordCount: transactions.length,
    );
  }

  /// Exports all core financial tables. SMS fingerprints and the Android
  /// pending-SMS review queue are intentionally excluded.
  Future<DataExportFile> exportFullFinancialBackup({
    DateTime? exportedAt,
  }) async {
    final accounts = await database.select(database.bankAccounts).get();
    final categories = await database.select(database.categories).get();
    final merchants = await database.select(database.merchants).get();
    final transactions =
        await database.select(database.moneyTransactions).get();
    final budgets = await database.select(database.budgets).get();
    final budgetTemplates =
        await database.select(database.budgetTemplates).get();
    final recurringSchedules =
        await database.select(database.recurringSchedules).get();

    final timestamp = exportedAt ?? DateTime.now();
    final tables = <String, Object?>{
      'bank_accounts': accounts
          .map((account) => <String, Object?>{
                'id': account.id,
                'bank_name': account.bankName,
                'account_name': account.accountName,
                'account_number_last4': account.accountNumberLast4,
                'opening_balance_paise': account.openingBalancePaise,
                'opening_date': account.openingDate.toIso8601String(),
                'is_active': account.isActive,
                'created_at': account.createdAt.toIso8601String(),
              })
          .toList(),
      'categories': categories
          .map((category) => <String, Object?>{
                'id': category.id,
                'name': category.name,
                'type': category.type,
                'icon_key': category.iconKey,
                'color_hex': category.colorHex,
                'is_system': category.isSystem,
              })
          .toList(),
      'merchants': merchants
          .map((merchant) => <String, Object?>{
                'id': merchant.id,
                'name': merchant.name,
                'default_category_id': merchant.defaultCategoryId,
              })
          .toList(),
      'money_transactions': transactions
          .map((transaction) => <String, Object?>{
                'id': transaction.id,
                'account_id': transaction.accountId,
                'transfer_to_account_id': transaction.transferToAccountId,
                'category_id': transaction.categoryId,
                'merchant_id': transaction.merchantId,
                'amount_paise': transaction.amountPaise,
                'transaction_type': transaction.transactionType,
                'description': transaction.description,
                'reference_number': transaction.referenceNumber,
                'transaction_date':
                    transaction.transactionDate.toIso8601String(),
                'source': transaction.source,
                'notes': transaction.notes,
                'created_at': transaction.createdAt.toIso8601String(),
              })
          .toList(),
      'budgets': budgets
          .map((budget) => <String, Object?>{
                'id': budget.id,
                'category_id': budget.categoryId,
                'month_start': budget.monthStart.toIso8601String(),
                'limit_paise': budget.limitPaise,
                'rollover_enabled': budget.rolloverEnabled,
                'created_at': budget.createdAt.toIso8601String(),
              })
          .toList(),
      'budget_templates': budgetTemplates
          .map((template) => <String, Object?>{
                'id': template.id,
                'category_id': template.categoryId,
                'start_month': template.startMonth.toIso8601String(),
                'limit_paise': template.limitPaise,
                'rollover_enabled': template.rolloverEnabled,
                'is_active': template.isActive,
                'created_at': template.createdAt.toIso8601String(),
              })
          .toList(),
      'recurring_schedules': recurringSchedules
          .map((schedule) => <String, Object?>{
                'id': schedule.id,
                'account_id': schedule.accountId,
                'category_id': schedule.categoryId,
                'amount_paise': schedule.amountPaise,
                'transaction_type': schedule.transactionType,
                'description': schedule.description,
                'frequency': schedule.frequency,
                'interval': schedule.interval,
                'start_date': schedule.startDate.toIso8601String(),
                'end_date': schedule.endDate?.toIso8601String(),
                'next_due_date': schedule.nextDueDate.toIso8601String(),
                'is_active': schedule.isActive,
                'created_at': schedule.createdAt.toIso8601String(),
              })
          .toList(),
    };

    final recordCount = accounts.length +
        categories.length +
        merchants.length +
        transactions.length +
        budgets.length +
        budgetTemplates.length +
        recurringSchedules.length;

    final backup = <String, Object?>{
      'format': 'artham_financial_backup',
      'format_version': 1,
      'app': 'Artham',
      'exported_at': timestamp.toIso8601String(),
      'currency': 'INR',
      'money_storage': 'integer_paise',
      'database_schema_version': database.schemaVersion,
      'record_count': recordCount,
      'tables': tables,
      'excluded_data': [
        'Processed SMS fingerprints',
        'Pending SMS review queue',
      ],
    };

    return DataExportFile(
      fileName: 'artham_full_backup_${_timeStamp(timestamp)}.json',
      mimeType: 'application/json',
      contents: const JsonEncoder.withIndent('  ').convert(backup),
      recordCount: recordCount,
    );
  }

  static String _csvLine(List<Object?> values) =>
      values.map((value) => _csvCell(value?.toString() ?? '')).join(',');

  /// Quotes every cell and neutralises spreadsheet formula prefixes in
  /// user-controlled text before a CSV is opened in Excel or Sheets.
  static String _csvCell(String value) {
    final firstNonWhitespace = value.trimLeft();
    if (RegExp(r'^[=+\-@]').hasMatch(firstNonWhitespace)) {
      value = "'${value}";
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _formatPaise(int paise) {
    final negative = paise < 0;
    final absolute = negative ? -paise : paise;
    final rupees = absolute ~/ 100;
    final subRupees = (absolute % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}${rupees}.${subRupees}';
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateStamp(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String _timeStamp(DateTime date) =>
      '${_dateStamp(date)}_'
      '${date.hour.toString().padLeft(2, '0')}'
      '${date.minute.toString().padLeft(2, '0')}'
      '${date.second.toString().padLeft(2, '0')}';
}
