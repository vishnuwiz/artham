import 'package:drift/drift.dart';
import '../app_database.dart';

class AccountRepository {
  final AppDatabase database;
  AccountRepository(this.database);

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

  Future<bool> updateAccount({
    required int accountId,
    required String bankName,
    required String accountName,
    required String accountNumberLast4,
    int? openingBalancePaise,
    DateTime? openingDate,
  }) async {
    final changed = await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(BankAccountsCompanion(
      bankName: Value(bankName),
      accountName: Value(accountName),
      accountNumberLast4: Value(accountNumberLast4),
      openingBalancePaise: openingBalancePaise == null
          ? const Value.absent()
          : Value(openingBalancePaise),
      openingDate: openingDate == null
          ? const Value.absent()
          : Value(openingDate),
    ));
    return changed > 0;
  }

  Future<BankAccount?> getAccountById(int accountId) {
    return (database.select(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .getSingleOrNull();
  }

  Future<bool> deactivateAccount(int accountId) async {
    final changed = await (database.update(database.bankAccounts)
          ..where((account) => account.id.equals(accountId)))
        .write(const BankAccountsCompanion(isActive: Value(false)));
    return changed > 0;
  }

  Future<List<BankAccount>> getActiveAccounts() {
    return (database.select(database.bankAccounts)
          ..where((account) => account.isActive.equals(true))
          ..orderBy([(account) => OrderingTerm.asc(account.bankName)]))
        .get();
  }
}
