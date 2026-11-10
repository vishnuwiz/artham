import 'package:drift/drift.dart';

import '../app_database.dart';
import 'merchant_repository.dart';

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

/// A transaction together with the account and category used to display it.
class RecentTransaction {
  final MoneyTransaction transaction;
  final BankAccount account;
  final Category? category;
  final Merchant? merchant;

  const RecentTransaction({
    required this.transaction,
    required this.account,
    required this.category,
    required this.merchant,
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
    if (transactionType != 'income' && transactionType != 'expense') {
      throw ArgumentError('Invalid transaction type');
    }

    if (amountPaise <= 0) {
      throw ArgumentError(
        'Transaction amount must be greater than zero',
      );
    }

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
              description == null || description.trim().isEmpty
                  ? null
                  : description.trim(),
            ),
            source: const Value('manual'),
          ),
        );
  }


  /// Update an existing income or expense transaction.
  Future<bool> updateTransaction({
    required int transactionId,
    required int accountId,
    required int categoryId,
    required int amountPaise,
    required String transactionType,
    required DateTime transactionDate,
    String? description,
    String? notes,
  }) async {
    if (transactionType != 'income' && transactionType != 'expense') {
      throw ArgumentError('Invalid transaction type');
    }

    if (amountPaise <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }

    final merchantId = await MerchantRepository(database)
        .findOrCreateForDescription(
      description: description,
      transactionType: transactionType,
      fallbackCategoryId: categoryId,
    );

    final updatedRows = await (database.update(database.moneyTransactions)
          ..where((transaction) => transaction.id.equals(transactionId)))
        .write(
      MoneyTransactionsCompanion(
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        merchantId: Value(merchantId),
        amountPaise: Value(amountPaise),
        transactionType: Value(transactionType),
        transactionDate: Value(transactionDate),
        description: Value(
          description == null || description.trim().isEmpty
              ? null
              : description.trim(),
        ),
        notes: Value(
          notes == null || notes.trim().isEmpty ? null : notes.trim(),
        ),
      ),
    );

    return updatedRows > 0;
  }

  /// Delete a transaction by its database ID.
  Future<bool> deleteTransaction(int transactionId) async {
    final deletedRows = await (database.delete(database.moneyTransactions)
          ..where((transaction) => transaction.id.equals(transactionId)))
        .go();

    return deletedRows > 0;
  }


  /// Record a transfer as one linked transaction row.
  /// The source account is debited and the destination account credited
  /// by getBalanceSummary(); transfers are not counted as income/expense.
  Future<int> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required int amountPaise,
    required DateTime transactionDate,
    String? description,
    String? referenceNumber,
    String? notes,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Choose two different accounts.');
    }
    if (amountPaise <= 0) {
      throw ArgumentError('Transfer amount must be greater than zero.');
    }

    final accounts = await getActiveAccounts();
    BankAccount? fromAccount;
    BankAccount? toAccount;
    for (final account in accounts) {
      if (account.id == fromAccountId) fromAccount = account;
      if (account.id == toAccountId) toAccount = account;
    }

    if (fromAccount == null || toAccount == null) {
      throw StateError('Both accounts must be active.');
    }
    if (transactionDate.isBefore(fromAccount.openingDate) ||
        transactionDate.isBefore(toAccount.openingDate)) {
      throw ArgumentError(
        'Transfer date cannot be earlier than either account opening date.',
      );
    }

    final summary = await getBalanceSummary();
    final availableBalance = summary.accountBalancesPaise[fromAccountId] ?? 0;
    if (availableBalance < amountPaise) {
      throw StateError('Insufficient balance in the source account.');
    }

    return database.into(database.moneyTransactions).insert(
      MoneyTransactionsCompanion.insert(
        accountId: fromAccountId,
        transferToAccountId: Value(toAccountId),
        categoryId: const Value.absent(),
        amountPaise: amountPaise,
        transactionType: 'transfer',
        transactionDate: transactionDate,
        description: Value(
          description == null || description.trim().isEmpty
              ? 'Transfer'
              : description.trim(),
        ),
        referenceNumber: Value(
          referenceNumber == null || referenceNumber.trim().isEmpty
              ? null
              : referenceNumber.trim(),
        ),
        notes: Value(
          notes == null || notes.trim().isEmpty ? null : notes.trim(),
        ),
        source: const Value('manual'),
      ),
    );
  }

  /// Fetch all transactions affecting one account, including incoming transfers.
  Future<List<MoneyTransaction>> getAccountTransactions(int accountId) async {
    final query = database.select(database.moneyTransactions)
      ..where((tx) =>
          tx.accountId.equals(accountId) |
          tx.transferToAccountId.equals(accountId))
      ..orderBy([
        (tx) => OrderingTerm.desc(tx.transactionDate),
        (tx) => OrderingTerm.desc(tx.createdAt),
      ]);
    return query.get();
  }

  // Get all transactions, newest first
  Future<List<MoneyTransaction>> getAllTransactions() {
    return (database.select(database.moneyTransactions)
          ..orderBy([
            (transaction) => OrderingTerm.desc(
                  transaction.transactionDate,
                ),
            (transaction) => OrderingTerm.desc(transaction.createdAt),
          ]))
        .get();
  }

  // Get the latest transactions with their bank account and category.
  // The account join is inner because a transaction must belong to an account.
  // The category join is left outer because categoryId can be null.
  Future<List<RecentTransaction>> getRecentTransactions({
    int limit = 5,
  }) async {
    if (limit <= 0) {
      return [];
    }

    final query = database.select(database.moneyTransactions).join([
      innerJoin(
        database.bankAccounts,
        database.bankAccounts.id.equalsExp(
          database.moneyTransactions.accountId,
        ),
      ),
      leftOuterJoin(
        database.categories,
        database.categories.id.equalsExp(
          database.moneyTransactions.categoryId,
        ),
      ),
      leftOuterJoin(
        database.merchants,
        database.merchants.id.equalsExp(
          database.moneyTransactions.merchantId,
        ),
      ),
    ]);

    query
      ..orderBy([
        OrderingTerm.desc(database.moneyTransactions.transactionDate),
        OrderingTerm.desc(database.moneyTransactions.createdAt),
      ])
      ..limit(limit);

    final rows = await query.get();

    return rows.map((row) {
      return RecentTransaction(
        transaction: row.readTable(database.moneyTransactions),
        account: row.readTable(database.bankAccounts),
        category: row.readTableOrNull(database.categories),
        merchant: row.readTableOrNull(database.merchants),
      );
    }).toList();
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

          if (destinationId != null && balances.containsKey(destinationId)) {
            final destinationAccount = accounts.firstWhere(
              (account) => account.id == destinationId,
            );

            if (!transactionDate.isBefore(
              destinationAccount.openingDate,
            )) {
              balances[destinationId] =
                  balances[destinationId]! + transaction.amountPaise;
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
    final activeAccountsById = {
      for (final account in accounts) account.id: account,
    };

    for (final transaction in transactions) {
      final date = transaction.transactionDate;
      final account = activeAccountsById[transaction.accountId];

      // Match balance calculations: ignore inactive accounts and entries
      // dated before the source account's opening date.
      if (account == null || date.isBefore(account.openingDate)) {
        continue;
      }

      if (date.isBefore(monthStart) || !date.isBefore(nextMonthStart)) {
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
