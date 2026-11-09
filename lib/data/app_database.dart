import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ==========================================
// 1. BANK ACCOUNTS
// ==========================================

class BankAccounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get bankName => text()();

  TextColumn get accountName => text()();

  TextColumn get accountNumberLast4 => text().nullable()();

  IntColumn get openingBalancePaise => integer()();

  DateTimeColumn get openingDate => dateTime()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// 2. CATEGORIES
// ==========================================

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get type => text()();
  // expense, income, transfer

  TextColumn get iconKey => text().nullable()();

  TextColumn get colorHex => text().nullable()();

  BoolColumn get isSystem =>
      boolean().withDefault(const Constant(false))();
}

// ==========================================
// 3. MERCHANTS
// ==========================================

class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  IntColumn get defaultCategoryId =>
      integer().nullable().references(Categories, #id)();
}

// ==========================================
// 4. FINANCIAL TRANSACTIONS
// ==========================================

class MoneyTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId =>
      integer().references(BankAccounts, #id)();

  IntColumn get transferToAccountId =>
      integer().nullable().references(BankAccounts, #id)();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  IntColumn get merchantId =>
      integer().nullable().references(Merchants, #id)();

  IntColumn get amountPaise => integer()();

  TextColumn get transactionType => text()();
  // income, expense, transfer

  TextColumn get description => text().nullable()();

  TextColumn get referenceNumber => text().nullable()();

  DateTimeColumn get transactionDate => dateTime()();

  TextColumn get source =>
      text().withDefault(const Constant('manual'))();
  // manual, sms, statement, recurring

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// 5. MONTHLY BUDGETS
// ==========================================

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  DateTimeColumn get monthStart => dateTime()();

  IntColumn get limitPaise => integer()();

  BoolColumn get rolloverEnabled =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// 5A. RECURRING MONTHLY BUDGET TEMPLATES
// ==========================================

class BudgetTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Null category means this template applies to the overall monthly budget.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  DateTimeColumn get startMonth => dateTime()();

  IntColumn get limitPaise => integer()();

  BoolColumn get rolloverEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// 6. PROCESSED SMS RECORDS
// ==========================================

class ProcessedSms extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get fingerprint => text().unique()();

  DateTimeColumn get receivedAt => dateTime()();

  BoolColumn get isProcessed =>
      boolean().withDefault(const Constant(false))();
}

// ==========================================
// 7. RECURRING TRANSACTION SCHEDULES
// ==========================================

class RecurringSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId =>
      integer().references(BankAccounts, #id)();

  IntColumn get categoryId =>
      integer().references(Categories, #id)();

  IntColumn get amountPaise => integer()();

  TextColumn get transactionType => text()();
  // income or expense

  TextColumn get description => text().nullable()();

  TextColumn get frequency => text()();
  // daily, weekly, monthly, yearly

  IntColumn get interval => integer().withDefault(const Constant(1))();
  // Repeat every N frequency units.

  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get endDate => dateTime().nullable()();

  DateTimeColumn get nextDueDate => dateTime()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// MAIN DATABASE
// ==========================================

@DriftDatabase(
  tables: [
    BankAccounts,
    Categories,
    Merchants,
    MoneyTransactions,
    Budgets,
    BudgetTemplates,
    ProcessedSms,
    RecurringSchedules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Creates an in-memory database for widget and repository tests.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(recurringSchedules);
          }
          if (from < 3) {
            await m.addColumn(budgets, budgets.rolloverEnabled);
          }
          if (from < 4) {
            await m.createTable(budgetTemplates);
          }
        },
      );

  Future<bool> testConnection() async {
    try {
      await customSelect('SELECT 1').getSingle();
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ==========================================
// DATABASE CONNECTION
// ==========================================

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      p.join(directory.path, 'artham.sqlite'),
    );

    return NativeDatabase.createInBackground(file);
  });
}

/// Returns a masked account identifier for display in the UI.
String accountNumberLastFourLabel(String? lastFourDigits) {
  final digits = lastFourDigits?.trim() ?? '';
  final valid = RegExp(r'^\d{4}.hasMatch(digits);
  return '•••• ${valid ? digits : '----'}';
}

/// Displays a bank account using its bank name and last four digits.
String bankAccountDisplayLabel(String bankName, String? lastFourDigits) {
  return '${bankName.trim()} · ${accountNumberLastFourLabel(lastFourDigits)}';
}

/// Keeps the legacy non-null database field populated without asking users
/// to provide a separate nickname. It is not used as a visible account label.
String legacyAccountNameForStorage(String? lastFourDigits) {
  final digits = lastFourDigits?.trim() ?? '';
  return digits.isEmpty ? 'Account' : 'Account $digits';
}
).hasMatch(digits);
  return '•••• ${valid ? digits : '----'}';
}

/// Displays a bank account using its bank name and last four digits.
String bankAccountDisplayLabel(String bankName, String? lastFourDigits) {
  return '${bankName.trim()} · ${accountNumberLastFourLabel(lastFourDigits)}';
}

/// Keeps the legacy non-null database field populated without asking users
/// to provide a separate nickname. It is not used as a visible account label.
String legacyAccountNameForStorage(String? lastFourDigits) {
  final digits = lastFourDigits?.trim() ?? '';
  return digits.isEmpty ? 'Account' : 'Account $digits';
}
