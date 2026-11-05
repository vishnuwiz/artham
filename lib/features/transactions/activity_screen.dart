import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import 'add_transaction_screen.dart';
import 'transaction_details_screen.dart';

const Color activityGreen = Color(0xFF13866A);
const Color activityNavy = Color(0xFF142B35);
const Color activityBackground = Color(0xFFF5F7F8);

enum _TransactionSort {
  newest,
  oldest,
  highest,
  lowest,
}

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

  String _selectedType = 'all';
  String _searchQuery = '';
  int? _selectedCategoryId;
  int? _selectedAccountId;
  DateTimeRange? _dateRange;
  _TransactionSort _sort = _TransactionSort.newest;

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
    final accounts =
        await widget.database.select(widget.database.bankAccounts).get();
    final categories =
        await widget.database.select(widget.database.categories).get();

    return _ActivityData(
      transactions: transactions,
      accountNames: {
        for (final account in accounts)
          account.id: '${account.bankName} · ${account.accountName}',
      },
      categoryNames: {
        for (final category in categories) category.id: category.name,
      },
      accounts: accounts,
      categories: categories,
    );
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(database: widget.database),
      ),
    );
    if (result == true && mounted) setState(_loadActivity);
  }

  Future<void> _openTransaction(MoneyTransaction transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailsScreen(
          database: widget.database,
          transaction: transaction,
        ),
      ),
    );
    if (result == true && mounted) setState(_loadActivity);
  }

  Future<void> _refresh() async {
    setState(_loadActivity);
    await _activityFuture;
  }

  String _formatAmount(int paise) =>
      '₹${(paise / 100).toStringAsFixed(2)}';

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today · ${_formatTime(date)}';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · ${_formatTime(date)}';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} · ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  List<MoneyTransaction> _applyFilters(_ActivityData data) {
    final query = _searchQuery.trim().toLowerCase();
    final result = data.transactions.where((tx) {
      if (_selectedType != 'all' && tx.transactionType != _selectedType) {
        return false;
      }
      if (_selectedCategoryId != null &&
          tx.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedAccountId != null &&
          tx.accountId != _selectedAccountId &&
          tx.transferToAccountId != _selectedAccountId) {
        return false;
      }
      if (_dateRange != null) {
        final date = tx.transactionDate;
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endExclusive = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day + 1,
        );
        if (date.isBefore(start) || !date.isBefore(endExclusive)) return false;
      }
      if (query.isNotEmpty) {
        final description = (tx.description ?? '').toLowerCase();
        final reference = (tx.referenceNumber ?? '').toLowerCase();
        final category =
            (data.categoryNames[tx.categoryId] ?? '').toLowerCase();
        final sourceAccount =
            (data.accountNames[tx.accountId] ?? '').toLowerCase();
        final destinationAccount =
            (data.accountNames[tx.transferToAccountId] ?? '').toLowerCase();
        if (!description.contains(query) &&
            !reference.contains(query) &&
            !category.contains(query) &&
            !sourceAccount.contains(query) &&
            !destinationAccount.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (_sort) {
      case _TransactionSort.newest:
        result.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      case _TransactionSort.oldest:
        result.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      case _TransactionSort.highest:
        result.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
      case _TransactionSort.lowest:
        result.sort((a, b) => a.amountPaise.compareTo(b.amountPaise));
    }
    return result;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedCategoryId != null) count++;
    if (_selectedAccountId != null) count++;
    if (_dateRange != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedType = 'all';
      _searchQuery = '';
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _dateRange = null;
      _sort = _TransactionSort.newest;
    });
  }

  Future<void> _openFilterSheet(_ActivityData data) async {
    var categoryId = _selectedCategoryId;
    var accountId = _selectedAccountId;
    var dateRange = _dateRange;

    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> chooseDates() async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(now.year + 2),
                initialDateRange: dateRange,
              );
              if (picked != null) {
                setSheetState(() => dateRange = picked);
              }
            }

            return SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  22 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: activityBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Filter transactions',
                              style: TextStyle(
                                color: activityNavy,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setSheetState(() {
                              categoryId = null;
                              accountId = null;
                              dateRange = null;
                            }),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        initialValue: categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ...data.categories.map(
                            (category) => DropdownMenuItem<int?>(
                              value: category.id,
                              child: Text(
                                '${category.name} (${category.type})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => categoryId = value),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        initialValue: accountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bank account',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All accounts'),
                          ),
                          ...data.accounts.map(
                            (account) => DropdownMenuItem<int?>(
                              value: account.id,
                              child: Text(
                                '${account.bankName} · ${account.accountName}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => accountId = value),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: chooseDates,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          dateRange == null
                              ? 'Choose date range'
                              : '${_shortDate(dateRange!.start)} – '
                                  '${_shortDate(dateRange!.end)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: activityGreen,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          _FilterSelection(
                            categoryId: categoryId,
                            accountId: accountId,
                            dateRange: dateRange,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: activityGreen,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        child: const Text('Apply filters'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategoryId = result.categoryId;
        _selectedAccountId = result.accountId;
        _dateRange = result.dateRange;
      });
    }
  }

  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_TransactionSort>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Sort transactions',
                style: TextStyle(
                  color: activityNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _sortOption('Newest first', _TransactionSort.newest),
            _sortOption('Oldest first', _TransactionSort.oldest),
            _sortOption('Highest amount', _TransactionSort.highest),
            _sortOption('Lowest amount', _TransactionSort.lowest),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  Widget _sortOption(String label, _TransactionSort value) {
    return ListTile(
      title: Text(label),
      trailing: _sort == value
          ? const Icon(Icons.check_circle, color: activityGreen)
          : null,
      onTap: () => Navigator.pop(context, value),
    );
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
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
          final transactions = _applyFilters(data);
          final income = transactions
              .where((tx) => tx.transactionType == 'income')
              .fold<int>(0, (sum, tx) => sum + tx.amountPaise);
          final expenses = transactions
              .where((tx) => tx.transactionType == 'expense')
              .fold<int>(0, (sum, tx) => sum + tx.amountPaise);

          return RefreshIndicator(
            color: activityGreen,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                _buildSummary(income, expenses),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search description or reference...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () =>
                                setState(() => _searchQuery = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTypeAndActionFilters(data),
                if (_dateRange != null ||
                    _selectedCategoryId != null ||
                    _selectedAccountId != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_dateRange != null)
                        _activeFilterChip(
                          '${_shortDate(_dateRange!.start)} – '
                          '${_shortDate(_dateRange!.end)}',
                        ),
                      if (_selectedCategoryId != null)
                        _activeFilterChip(
                          data.categoryNames[_selectedCategoryId] ?? 'Category',
                        ),
                      if (_selectedAccountId != null)
                        _activeFilterChip(
                          data.accountNames[_selectedAccountId] ?? 'Account',
                        ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
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
                      '${transactions.length} records',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Sort',
                      onPressed: _openSortSheet,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.sort_rounded,
                        color: activityNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (transactions.isEmpty)
                  _buildNoResults()
                else
                  ...transactions.map((tx) => _buildTransactionCard(tx, data)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeAndActionFilters(_ActivityData data) {
    const types = [
      ('All', 'all'),
      ('Income', 'income'),
      ('Expenses', 'expense'),
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: types.map((item) {
                final selected = _selectedType == item.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(item.$1),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedType = item.$2),
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
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Filter by category, account or date',
          onPressed: () => _openFilterSheet(data),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: activityGreen,
          ),
          icon: Badge(
            isLabelVisible: _activeFilterCount > 0,
            label: Text('$_activeFilterCount'),
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _activeFilterChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: activityGreen.withValues(alpha: 0.10),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSummary(int income, int expenses) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [Color(0xFF142B35), Color(0xFF176B59)],
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
            'Based on current filters',
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildTransactionCard(
    MoneyTransaction transaction,
    _ActivityData data,
  ) {
    final isTransfer = transaction.transactionType == 'transfer';
    final isIncome = transaction.transactionType == 'income';
    final color = isTransfer
        ? const Color(0xFF54758A)
        : isIncome
            ? activityGreen
            : const Color(0xFFC45D58);
    final categoryName = isTransfer
        ? 'Transfer'
        : data.categoryNames[transaction.categoryId] ?? 'Uncategorised';
    final sourceAccount =
        data.accountNames[transaction.accountId] ?? 'Inactive account';
    final destinationAccount = transaction.transferToAccountId == null
        ? null
        : data.accountNames[transaction.transferToAccountId];
    final accountName = isTransfer && destinationAccount != null
        ? '$sourceAccount → $destinationAccount'
        : sourceAccount;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTransaction(transaction),
          child: Padding(
            padding: const EdgeInsets.all(15),
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
                    isTransfer
                        ? Icons.swap_horiz_rounded
                        : _categoryIcon(categoryName),
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
          ),
        ),
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

  Widget _buildNoResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: activityGreen,
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            'No matching transactions',
            style: TextStyle(
              color: activityNavy,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear search and filters'),
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
  final List<BankAccount> accounts;
  final List<Category> categories;

  const _ActivityData({
    required this.transactions,
    required this.accountNames,
    required this.categoryNames,
    required this.accounts,
    required this.categories,
  });
}

class _FilterSelection {
  final int? categoryId;
  final int? accountId;
  final DateTimeRange? dateRange;

  const _FilterSelection({
    required this.categoryId,
    required this.accountId,
    required this.dateRange,
  });
}
