
import 'package:drift/drift.dart';

import '../app_database.dart';

class AccountRepository {
  final AppDatabase database;

  AccountRepository(this.database);

  // Add a new bank account
  Future<int> addAccount({
    required String bankName,
    required String accountName,
    required String accountNumberLast4,
    required int openingBalancePaise,
    required DateTime openingDate,
  }) async {
    return database.into(database.bankAccounts).insert(
          BankAccountsCompanion.insert(
            bankName: bankName,
            accountName: accountName,
            accountNumberLast4: Value(accountNumberLast4),
            openingBalancePaise: openingBalancePaise,
            openingDate: openingDate,
          ),
        );
  }

  // Retrieve all active bank accounts
  Future<List<BankAccount>> getActiveAccounts() {
    return (database.select(database.bankAccounts)
          ..where((account) => account.isActive.equals(true))
          ..orderBy([
            (account) => OrderingTerm.asc(account.bankName),
          ]))
        .get();
  }

  // Retrieve a single bank account by ID
  Future<BankAccount?> getAccountById(int accountId) {
    return (database.select(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .getSingleOrNull();
  }

  // Update an existing bank account
  Future<bool> updateAccount({
    required int accountId,
    required String bankName,
    required String accountName,
    required String accountNumberLast4,
    required int openingBalancePaise,
    required DateTime openingDate,
  }) async {
    final updatedRows = await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(
      BankAccountsCompanion(
        bankName: Value(bankName),
        accountName: Value(accountName),
        accountNumberLast4: Value(accountNumberLast4),
        openingBalancePaise: Value(openingBalancePaise),
        openingDate: Value(openingDate),
      ),
    );

    return updatedRows > 0;
  }

  // Deactivate an account without deleting its data
  Future<bool> deactivateAccount(int accountId) async {
    final updatedRows = await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(
      const BankAccountsCompanion(
        isActive: Value(false),
      ),
    );

    return updatedRows > 0;
  }

  // Reactivate a previously deactivated account
  Future<bool> reactivateAccount(int accountId) async {
    final updatedRows = await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(
      const BankAccountsCompanion(
        isActive: Value(true),
      ),
    );

    return updatedRows > 0;
  }
}
