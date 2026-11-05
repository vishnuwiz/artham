
import 'package:drift/drift.dart';

import '../app_database.dart';

class AccountBalanceSummary {
  final Map<int, int> accountBalancesPaise;
  final int totalBalancePaise;
  final int monthlyIncomePaise;
  final int monthlyExpensesPaise;

  const AccountBalanceSummary({
    required this.accountBalancesPaise,
    required this.totalBalancePaise,
    required this.monthlyIncomePaise,
    required this.monthlyExpensesPaise,
  });
}

class TransactionRepository {
  final AppDatabase database;

  TransactionRepository(this.database);

  // Default categories for Artham
  static const Map<String, List<String>> defaultCategories = {
    'income': [
      'Salary',
      'Business Income',
      'Interest',
      'Investment Returns',
      'Gift',
      'Other Income',
    ],
    'expense': [
      'Food & Dining',
      'Shopping',
      'Transportation',
      'Bills & Utilities',
      'Entertainment',
      'Health',
      'Education',
      'Travel',
      'Groceries',
      'Rent',
      'Other Expense',
    ],
  };

  // Create default categories if they don't already exist
  Future<void> seedDefaultCategories() async {
    for (final entry in defaultCategories.entries) {
      for (final categoryName in entry.value) {
        final existing = await (database.select(database.categories)
              ..where((category) =>
                  category.name.equals(categoryName) &
                  category.type.equals(entry.key)))
            .getSingleOrNull();

        if (existing == null) {
          await database.into(database.categories).insert(
                CategoriesCompanion.insert(
                  name: categoryName,
                  type: entry.key,
                  isSystem: const Value(true),
                ),
              );
        }
      }
    }
  }

  // Get categories for income or expense
  Future<List<Category>> getCategories(String type) {
    return (database.select(database.categories)
          ..where((category) => category.type.equals(type))
          ..orderBy([
            (category) => OrderingTerm.asc(category.name),
          ]))
        .get();
  }

  // Get active bank accounts
  Future<List<BankAccount>> getActiveAccounts() {
    return (database.select(database.bankAccounts)
          ..where((account) => account.isActive.equals(true))
          ..orderBy([
            (account) => OrderingTerm.asc(account.bankName),
          ]))
        .get();
  }

  // Add an income or expense transaction
  Future<int> addTransaction({
    required int accountId,
    required int categoryId,
    required int amountPaise,
    required String transactionType,
    required DateTime transactionDate,
    String? description,
  }) async {
    if (transactionType != 'income' &&
        transactionType != 'expense') {
      throw ArgumentError('Invalid transaction type');
    }

    if (amountPaise <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero',
      );
    }

    return database.into(database.moneyTransactions).insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: amountPaise,
            transactionType: transactionType,
            transactionDate: transactionDate,
            description: Value(
              description == null || description.trim().isEmpty
                  ? null
                  : description.trim(),
            ),
            source: const Value('manual'),
          ),
        );
  }

  // Get all transactions, newest first
  Future<List<MoneyTransaction>> getAllTransactions() {
    return (database.select(database.moneyTransactions)
          ..orderBy([
            (transaction) => OrderingTerm.desc(
                  transaction.transactionDate,
                ),
            (transaction) =>
                OrderingTerm.desc(transaction.createdAt),
          ]))
        .get();
  }

  // Calculate balances for every active bank account.
  // Transactions before the account's opening date are ignored.
  // Transfers are included as money movement, not income or expense.
  Future<AccountBalanceSummary> getBalanceSummary() async {
    final accounts = await getActiveAccounts();
    final transactions = await getAllTransactions();

    final balances = <int, int>{
      for (final account in accounts)
        account.id: account.openingBalancePaise,
    };

    for (final transaction in transactions) {
      final sourceBalance = balances[transaction.accountId];

      // Ignore transactions that belong to an account not included
      // in the active accounts list.
      if (sourceBalance == null) continue;

      final transactionDate = transaction.transactionDate;
      final sourceAccount = accounts.firstWhere(
        (account) => account.id == transaction.accountId,
      );

      if (transactionDate.isBefore(sourceAccount.openingDate)) {
        continue;
      }

      switch (transaction.transactionType) {
        case 'income':
          balances[transaction.accountId] =
              sourceBalance + transaction.amountPaise;
          break;

        case 'expense':
          balances[transaction.accountId] =
              sourceBalance - transaction.amountPaise;
          break;

        case 'transfer':
          balances[transaction.accountId] =
              sourceBalance - transaction.amountPaise;

          final destinationId = transaction.transferToAccountId;

          if (destinationId != null &&
              balances.containsKey(destinationId)) {
            final destinationAccount = accounts.firstWhere(
              (account) => account.id == destinationId,
            );

            if (!transactionDate.isBefore(
              destinationAccount.openingDate,
            )) {
              balances[destinationId] =
                  balances[destinationId]! +
                      transaction.amountPaise;
            }
          }
          break;
      }
    }

    final totalBalance = balances.values.fold<int>(
      0,
      (sum, balance) => sum + balance,
    );

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    int monthlyIncome = 0;
    int monthlyExpenses = 0;

    for (final transaction in transactions) {
      final date = transaction.transactionDate;

      if (date.isBefore(monthStart) ||
          !date.isBefore(nextMonthStart)) {
        continue;
      }

      if (transaction.transactionType == 'income') {
        monthlyIncome += transaction.amountPaise;
      } else if (transaction.transactionType == 'expense') {
        monthlyExpenses += transaction.amountPaise;
      }
    }

    return AccountBalanceSummary(
      accountBalancesPaise: balances,
      totalBalancePaise: totalBalance,
      monthlyIncomePaise: monthlyIncome,
      monthlyExpensesPaise: monthlyExpenses,
    );
  }
}
