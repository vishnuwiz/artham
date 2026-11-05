
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import 'add_transaction_screen.dart';

const Color activityGreen = Color(0xFF13866A);
const Color activityNavy = Color(0xFF142B35);
const Color activityBackground = Color(0xFFF5F7F8);

class ActivityScreen extends StatefulWidget {
  final AppDatabase database;

  const ActivityScreen({
    super.key,
    required this.database,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final TransactionRepository _repository;
  late Future<_ActivityData> _activityFuture;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _loadActivity();
  }

  void _loadActivity() {
    _activityFuture = _fetchActivity();
  }

  Future<_ActivityData> _fetchActivity() async {
    final transactions = await _repository.getAllTransactions();
    final accounts = await _repository.getActiveAccounts();
    final incomeCategories = await _repository.getCategories('income');
    final expenseCategories = await _repository.getCategories('expense');

    final accountNames = {
      for (final account in accounts)
        account.id: '${account.bankName} · ${account.accountName}',
    };

    final categoryNames = {
      for (final category in [...incomeCategories, ...expenseCategories])
        category.id: category.name,
    };

    return _ActivityData(
      transactions: transactions,
      accountNames: accountNames,
      categoryNames: categoryNames,
    );
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          database: widget.database,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(_loadActivity);
    }
  }

  Future<void> _refresh() async {
    setState(_loadActivity);
    await _activityFuture;
  }

  String _formatAmount(int paise) {
    return '₹${(paise / 100).toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(date.year, date.month, date.day);

    if (transactionDay == today) {
      return 'Today · ${_formatTime(date)}';
    }

    if (transactionDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · ${_formatTime(date)}';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} · ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: activityBackground,
      appBar: AppBar(
        backgroundColor: activityBackground,
        foregroundColor: activityNavy,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        backgroundColor: activityGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction'),
      ),
      body: FutureBuilder<_ActivityData>(
        future: _activityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: activityGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load transactions:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          final filteredTransactions = data.transactions.where((tx) {
            if (_selectedFilter == 'all') return true;
            return tx.transactionType == _selectedFilter;
          }).toList();

          final totalIncome = data.transactions
              .where((tx) => tx.transactionType == 'income')
              .fold<int>(0, (sum, tx) => sum + tx.amountPaise);

          final totalExpenses = data.transactions
              .where((tx) => tx.transactionType == 'expense')
              .fold<int>(0, (sum, tx) => sum + tx.amountPaise);

          return RefreshIndicator(
            color: activityGreen,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                _buildSummary(totalIncome, totalExpenses),
                const SizedBox(height: 24),
                _buildFilters(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        color: activityNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredTransactions.length} records',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filteredTransactions.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredTransactions.map(
                    (tx) => _buildTransactionCard(
                      tx,
                      data,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(int income, int expenses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: activityNavy,
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF142B35),
            Color(0xFF176B59),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRANSACTION SUMMARY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Income',
                  _formatAmount(income),
                  Icons.trending_up_rounded,
                  const Color(0xFF68DFB4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryItem(
                  'Expenses',
                  _formatAmount(expenses),
                  Icons.trending_down_rounded,
                  const Color(0xFFFFA69A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Net movement',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                _formatAmount(income - expenses),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'All recorded transactions',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Income', 'value': 'income'},
      {'label': 'Expenses', 'value': 'expense'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: ChoiceChip(
              label: Text(filter['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter['value']!;
                });
              },
              selectedColor: activityGreen.withValues(alpha: 0.13),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? activityGreen : Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected
                    ? activityGreen.withValues(alpha: 0.3)
                    : const Color(0xFFE5E9EB),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionCard(
    MoneyTransaction transaction,
    _ActivityData data,
  ) {
    final isIncome = transaction.transactionType == 'income';
    final color = isIncome ? activityGreen : const Color(0xFFC45D58);

    final categoryName =
        data.categoryNames[transaction.categoryId] ?? 'Uncategorised';

    final accountName =
        data.accountNames[transaction.accountId] ?? 'Inactive account';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _categoryIcon(categoryName),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description?.isNotEmpty == true
                      ? transaction.description!
                      : categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: activityNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$categoryName · $accountName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.transactionDate),
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIncome ? '+' : '−'}${_formatAmount(transaction.amountPaise)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
      case 'groceries':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'transportation':
      case 'travel':
        return Icons.directions_car_rounded;
      case 'bills & utilities':
      case 'rent':
        return Icons.receipt_long_rounded;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'salary':
      case 'business income':
        return Icons.account_balance_wallet_outlined;
      case 'interest':
      case 'investment returns':
        return Icons.trending_up_rounded;
      default:
        return Icons.currency_rupee_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: activityGreen,
            size: 55,
          ),
          const SizedBox(height: 15),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: activityNavy,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Your recorded income and expenses will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 17),
          OutlinedButton.icon(
            onPressed: _addTransaction,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first transaction'),
            style: OutlinedButton.styleFrom(
              foregroundColor: activityGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityData {
  final List<MoneyTransaction> transactions;
  final Map<int, String> accountNames;
  final Map<int, String> categoryNames;

  const _ActivityData({
    required this.transactions,
    required this.accountNames,
    required this.categoryNames,
  });
}
