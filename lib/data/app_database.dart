
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
  // manual, sms, statement

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
// MAIN DATABASE
// ==========================================

@DriftDatabase(
  tables: [
    BankAccounts,
    Categories,
    Merchants,
    MoneyTransactions,
    Budgets,
    ProcessedSms,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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
