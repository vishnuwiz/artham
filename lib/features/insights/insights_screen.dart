import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

const Color _insightsGreen = Color(0xFF13866A);
const Color _insightsNavy = Color(0xFF142B35);
const Color _insightsBackground = Color(0xFFF5F7F8);

class InsightsScreen extends StatefulWidget {
  final AppDatabase database;
  final bool isActive;

  const InsightsScreen({
    super.key,
    required this.database,
    this.isActive = true,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<_InsightsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadData();
    }
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_InsightsData> _fetchData() async {
    final repository = TransactionRepository(widget.database);
    final transactions = await repository.getAllTransactions();
    final categories = await repository.getCategories('expense');
    final now = DateTime.now();

    final monthData = <_MonthTotals>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      var income = 0;
      var expenses = 0;

      for (final transaction in transactions) {
        if (transaction.transactionDate.isBefore(month) ||
            !transaction.transactionDate.isBefore(nextMonth)) {
          continue;
        }
        if (transaction.transactionType == 'income') {
          income += transaction.amountPaise;
        } else if (transaction.transactionType == 'expense') {
          expenses += transaction.amountPaise;
        }
      }

      monthData.add(_MonthTotals(month: month, income: income, expenses: expenses));
    }

    final currentStart = DateTime(now.year, now.month, 1);
    final nextStart = DateTime(now.year, now.month + 1, 1);
    var currentIncome = 0;
    var currentExpenses = 0;
    final categoryTotals = <int, int>{};

    for (final transaction in transactions) {
      final date = transaction.transactionDate;
      if (date.isBefore(currentStart) || !date.isBefore(nextStart)) continue;

      if (transaction.transactionType == 'income') {
        currentIncome += transaction.amountPaise;
      } else if (transaction.transactionType == 'expense') {
        currentExpenses += transaction.amountPaise;
        final categoryId = transaction.categoryId;
        if (categoryId != null) {
          categoryTotals[categoryId] =
              (categoryTotals[categoryId] ?? 0) + transaction.amountPaise;
        }
      }
    }

    final categoryData = categories
        .map((category) => _CategoryTotal(
              name: category.name,
              amount: categoryTotals[category.id] ?? 0,
            ))
        .where((item) => item.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return _InsightsData(
      monthTotals: monthData,
      currentIncome: currentIncome,
      currentExpenses: currentExpenses,
      categoryTotals: categoryData,
    );
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  String _monthShort(DateTime date) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[date.month - 1];
  }

  String _monthLong(DateTime date) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${names[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _insightsBackground,
      body: SafeArea(
        child: FutureBuilder<_InsightsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _insightsGreen),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load insights. Please try again.'));
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('No insights available.'));
            }

            final netSavings = data.currentIncome - data.currentExpenses;
            final savingsRate = data.currentIncome > 0
                ? netSavings / data.currentIncome
                : 0.0;

            return RefreshIndicator(
              color: _insightsGreen,
              onRefresh: () async {
                setState(_loadData);
                await _dataFuture;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const Text(
                          'Insights',
                          style: TextStyle(
                            color: _insightsNavy,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Your financial overview · ${_monthLong(DateTime.now())}',
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        _buildSavingsCard(data, netSavings, savingsRate),
                        const SizedBox(height: 25),
                        _sectionTitle('Income vs expenses', 'Last 6 months'),
                        const SizedBox(height: 12),
                        _buildMonthlyChart(data.monthTotals),
                        const SizedBox(height: 25),
                        _sectionTitle('Where your money goes', 'This month'),
                        const SizedBox(height: 12),
                        _buildCategoryBreakdown(data.categoryTotals, data.currentExpenses),
                        const SizedBox(height: 20),
                        const Text(
                          'Insights are based on transactions saved in Artham. Transfers are excluded.',
                          style: TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(
            color: _insightsNavy, fontSize: 18, fontWeight: FontWeight.w800,
          )),
        ),
        Text(subtitle, style: const TextStyle(color: _insightsGreen, fontSize: 11,
          fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildSavingsCard(_InsightsData data, int netSavings, double savingsRate) {
    final positive = netSavings >= 0;
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
          const Text('NET SAVINGS THIS MONTH',
            style: TextStyle(color: Colors.white70, fontSize: 11,
              letterSpacing: 1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          Text(_money(netSavings.abs()),
            style: const TextStyle(color: Colors.white, fontSize: 30,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(positive ? 'You are spending within your income' : 'Expenses exceed income',
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _whiteMetric('INCOME', _money(data.currentIncome))),
              Expanded(child: _whiteMetric('EXPENSES', _money(data.currentExpenses))),
              Expanded(child: _whiteMetric('SAVINGS RATE',
                '${(savingsRate * 100).toStringAsFixed(1)}%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whiteMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        const SizedBox(height: 6),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildMonthlyChart(List<_MonthTotals> months) {
    final maxValue = months.fold<int>(0, (max, item) {
      final monthMax = item.income > item.expenses ? item.income : item.expenses;
      return monthMax > max ? monthMax : max;
    });
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)),
      child: Column(
        children: [
          Row(
            children: [
              _legend(const Color(0xFF13866A), 'Income'),
              const SizedBox(width: 18),
              _legend(const Color(0xFFFFA69A), 'Expenses'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.map((item) {
                final incomeHeight = maxValue == 0 ? 0.0 : 105 * item.income / maxValue;
                final expenseHeight = maxValue == 0 ? 0.0 : 105 * item.expenses / maxValue;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(incomeHeight),
                            const SizedBox(width: 4),
                            _bar(expenseHeight, color: const Color(0xFFFFA69A)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_monthShort(item.month),
                        style: const TextStyle(color: Colors.black54, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double height, {Color color = _insightsGreen}) {
    return Container(
      width: 9,
      height: height.clamp(2.0, 105.0).toDouble(),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 9, height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ],
    );
  }

  Widget _buildCategoryBreakdown(List<_CategoryTotal> categories, int total) {
    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(
          children: [
            Icon(Icons.pie_chart_outline_rounded, color: _insightsGreen, size: 34),
            SizedBox(height: 8),
            Text('No expenses recorded this month',
              style: TextStyle(color: _insightsNavy, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Your category breakdown will appear here.',
              style: TextStyle(color: Colors.black54, fontSize: 11)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)),
      child: Column(
        children: categories.map((item) {
          final share = total > 0 ? item.amount / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name,
                      style: const TextStyle(color: _insightsNavy,
                        fontSize: 13, fontWeight: FontWeight.w700))),
                    Text(_money(item.amount),
                      style: const TextStyle(color: _insightsNavy,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0).toDouble(),
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE9EEEC),
                    color: _insightsGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(share * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.black45, fontSize: 10)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InsightsData {
  final List<_MonthTotals> monthTotals;
  final int currentIncome;
  final int currentExpenses;
  final List<_CategoryTotal> categoryTotals;

  const _InsightsData({
    required this.monthTotals,
    required this.currentIncome,
    required this.currentExpenses,
    required this.categoryTotals,
  });
}

class _MonthTotals {
  final DateTime month;
  final int income;
  final int expenses;

  const _MonthTotals({
    required this.month,
    required this.income,
    required this.expenses,
  });
}

class _CategoryTotal {
  final String name;
  final int amount;

  const _CategoryTotal({required this.name, required this.amount});
}
