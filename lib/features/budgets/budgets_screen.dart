import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/budget_repository.dart';

const Color _green = Color(0xFF13866A);
const Color _navy = Color(0xFF142B35);

class BudgetsScreen extends StatefulWidget {
  final AppDatabase database;
  final bool isActive;

  const BudgetsScreen({
    super.key,
    required this.database,
    this.isActive = true,
  });

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

enum _BudgetDialogAction { save, remove }

class _BudgetDialogResult {
  final _BudgetDialogAction action;
  final String amount;

  const _BudgetDialogResult({required this.action, this.amount = ''});
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late DateTime _selectedMonth;
  late Future<_BudgetScreenData> _dataFuture;

  BudgetRepository get _repository => BudgetRepository(widget.database);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant BudgetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload database values whenever the user returns to the Budgets tab.
    if (!oldWidget.isActive && widget.isActive) {
      _loadData();
    }
  }

  void _loadData() {
    _dataFuture = _fetchData();
  }

  Future<_BudgetScreenData> _fetchData() async {
    final overall = await _repository.getMonthlyBudgetSummary(_selectedMonth);
    final categories =
        await _repository.getCategoryBudgetSummaries(_selectedMonth);
    return _BudgetScreenData(overall: overall, categories: categories);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
      _loadData();
    });
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  Future<void> _editBudget({
    required String title,
    required int? categoryId,
    required int currentPaise,
  }) async {
    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (_) => _BudgetLimitDialog(
        title: title,
        initialAmount: currentPaise > 0
            ? (currentPaise / 100).toStringAsFixed(2)
            : '',
        canRemove: currentPaise > 0,
      ),
    );

    if (!mounted || result == null) return;

    if (result.action == _BudgetDialogAction.remove) {
      final shouldRemove = await showDialog<bool>(
        context: context,
        builder: (confirmContext) => AlertDialog(
          title: const Text('Remove budget?'),
          content: Text(
            'This will remove the ${categoryId == null ? 'overall' : 'category'} '
            'budget limit for ${_monthLabel(_selectedMonth)}. '
            'Your transactions and account balances will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(confirmContext, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (!mounted || shouldRemove != true) return;

      if (categoryId == null) {
        await _repository.deleteMonthlyBudget(_selectedMonth);
      } else {
        await _repository.deleteCategoryBudget(
          month: _selectedMonth,
          categoryId: categoryId,
        );
      }

      if (!mounted) return;
      setState(_loadData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget limit removed')),
      );
      return;
    }

    final amount = double.parse(result.amount.trim().replaceAll(',', ''));
    final paise = (amount * 100).round();

    if (categoryId == null) {
      await _repository.saveMonthlyBudget(
        month: _selectedMonth,
        limitPaise: paise,
      );
    } else {
      await _repository.saveCategoryBudget(
        month: _selectedMonth,
        categoryId: categoryId,
        limitPaise: paise,
      );
    }

    if (!mounted) return;
    setState(_loadData);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Budget saved successfully')),
    );
  }

  Future<void> _openBudgetHistory() async {
    final history = await _repository.getMonthlyBudgetHistory(months: 12);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        DateTime? expandedMonth = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          1,
        );
        Future<List<CategoryBudgetSummary>>? categoryFuture =
            _repository.getCategoryBudgetSummaries(expandedMonth);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.86,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Budget history',
                              style: TextStyle(
                                color: _navy,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select a month to see its category-wise spending and limits.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = history[history.length - 1 - index];
                          final hasBudget = item.hasBudget;
                          final over = hasBudget && item.remainingPaise < 0;
                          final isSelected =
                              item.month.year == _selectedMonth.year &&
                              item.month.month == _selectedMonth.month;
                          final isExpanded = expandedMonth != null &&
                              item.month.year == expandedMonth!.year &&
                              item.month.month == expandedMonth!.month;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: Column(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(17),
                                  onTap: () {
                                    setSheetState(() {
                                      if (isExpanded) {
                                        expandedMonth = null;
                                        categoryFuture = null;
                                      } else {
                                        expandedMonth = item.month;
                                        categoryFuture = _repository
                                            .getCategoryBudgetSummaries(item.month);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _monthLabel(item.month),
                                                style: const TextStyle(
                                                  color: _navy,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Text(
                                                'VIEWING',
                                                style: TextStyle(
                                                  color: _green,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              isExpanded
                                                  ? Icons.expand_less_rounded
                                                  : Icons.expand_more_rounded,
                                              color: Colors.black38,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Spent  ${_money(item.expensesPaise)}',
                                          style: const TextStyle(
                                            color: _navy,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          hasBudget
                                              ? 'Budget  ${_money(item.budgetPaise!)}  ·  ${over ? '${_money(item.remainingPaise.abs())} over' : '${_money(item.remainingPaise)} left'}'
                                              : 'No overall budget set',
                                          style: TextStyle(
                                            color: over
                                                ? const Color(0xFFC45D58)
                                                : Colors.black54,
                                            fontSize: 11,
                                            fontWeight: over
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isExpanded) ...[
                                  const Divider(height: 1, indent: 15, endIndent: 15),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(15, 12, 15, 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'CATEGORY BREAKDOWN',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        FutureBuilder<List<CategoryBudgetSummary>>(
                                          future: categoryFuture,
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Padding(
                                                padding: EdgeInsets.all(16),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    color: _green,
                                                  ),
                                                ),
                                              );
                                            }
                                            if (snapshot.hasError) {
                                              return const Text(
                                                'Unable to load category history.',
                                                style: TextStyle(
                                                  color: Color(0xFFC45D58),
                                                  fontSize: 12,
                                                ),
                                              );
                                            }
                                            final categories = snapshot.data ?? [];
                                            if (categories.isEmpty) {
                                              return const Text(
                                                'No expense categories found.',
                                                style: TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12,
                                                ),
                                              );
                                            }
                                            return Column(
                                              children: categories
                                                  .map(_buildHistoryCategoryRow)
                                                  .toList(),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              Navigator.pop(sheetContext);
                                              setState(() {
                                                _selectedMonth = DateTime(
                                                  item.month.year,
                                                  item.month.month,
                                                  1,
                                                );
                                                _loadData();
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('View this month'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCategoryRow(CategoryBudgetSummary item) {
    final hasBudget = item.budgetPaise > 0;
    final over = hasBudget && item.remainingPaise < 0;
    final ratio = hasBudget ? item.percentageUsed : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category.name,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _money(item.expensesPaise),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            hasBudget
                ? 'Budget ${_money(item.budgetPaise)}  ·  ${over ? '${_money(item.remainingPaise.abs())} over' : '${_money(item.remainingPaise)} left'}'
                : 'No category budget set',
            style: TextStyle(
              color: over ? const Color(0xFFC45D58) : Colors.black54,
              fontSize: 10,
            ),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 5,
                backgroundColor: const Color(0xFFE9EEEC),
                color: over ? const Color(0xFFC45D58) : _green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: FutureBuilder<_BudgetScreenData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load budgets. Please try again.'),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('No budget data available.'));
            }

            return RefreshIndicator(
              color: _green,
              onRefresh: () async {
                setState(_loadData);
                await _dataFuture;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Budgets',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Budget history',
                              onPressed: _openBudgetHistory,
                              icon: const Icon(Icons.history_rounded),
                            ),
                            IconButton(
                              onPressed: () => _changeMonth(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              _monthLabel(_selectedMonth),
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _changeMonth(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildOverallCard(data.overall),
                        _buildBudgetAlerts(data),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Category budgets',
                                style: TextStyle(
                                  color: _navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${data.categories.where((item) => item.budgetPaise > 0).length} set',
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...data.categories.map(_buildCategoryCard),
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

  List<_BudgetAlert> _getBudgetAlerts(_BudgetScreenData data) {
    final alerts = <_BudgetAlert>[];

    final overall = data.overall;
    if (overall != null && overall.budgetPaise > 0) {
      final percentage = overall.expensesPaise / overall.budgetPaise;
      if (percentage >= 0.8) {
        alerts.add(_BudgetAlert(
          title: 'Overall monthly budget',
          spentPaise: overall.expensesPaise,
          budgetPaise: overall.budgetPaise,
          percentage: percentage,
          exceeded: percentage >= 1.0,
        ));
      }
    }

    for (final category in data.categories) {
      if (category.budgetPaise <= 0) continue;

      final percentage = category.percentageUsed;
      if (percentage >= 0.8) {
        alerts.add(_BudgetAlert(
          title: category.category.name,
          spentPaise: category.expensesPaise,
          budgetPaise: category.budgetPaise,
          percentage: percentage,
          exceeded: percentage >= 1.0,
        ));
      }
    }

    // Show the most urgent alerts first.
    alerts.sort((a, b) {
      if (a.exceeded != b.exceeded) return a.exceeded ? -1 : 1;
      return b.percentage.compareTo(a.percentage);
    });

    return alerts;
  }

  Widget _buildBudgetAlerts(_BudgetScreenData data) {
    final alerts = _getBudgetAlerts(data);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Budget alerts',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${alerts.length} ${alerts.length == 1 ? 'alert' : 'alerts'}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.map(_buildBudgetAlertCard),
        ],
      ),
    );
  }

  Widget _buildBudgetAlertCard(_BudgetAlert alert) {
    final color = alert.exceeded
        ? const Color(0xFFC45D58)
        : const Color(0xFFB7791F);
    final background = alert.exceeded
        ? const Color(0xFFFFF0EE)
        : const Color(0xFFFFF7E8);
    final icon = alert.exceeded
        ? Icons.error_outline_rounded
        : Icons.warning_amber_rounded;
    final percentage = (alert.percentage * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.exceeded
                      ? 'Budget exceeded · $percentage% used'
                      : 'You have used $percentage% of this budget',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_money(alert.spentPaise)} spent of ${_money(alert.budgetPaise)}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallCard(MonthlyBudgetSummary? summary) {
    final budget = summary?.budgetPaise ?? 0;
    final spent = summary?.expensesPaise ?? 0;
    final remaining = summary?.remainingPaise ?? 0;
    final hasBudget = summary != null;
    final ratio = hasBudget && budget > 0 ? spent / budget : 0.0;
    final over = hasBudget && remaining < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
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
            'TOTAL MONTHLY BUDGET',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasBudget ? _money(budget) : 'Not set',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _summaryValue('SPENT', _money(spent))),
              Expanded(
                child: _summaryValue(
                  over ? 'OVER BUDGET' : 'REMAINING',
                  hasBudget ? _money(remaining.abs()) : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              backgroundColor: Colors.white24,
              color: over ? const Color(0xFFFFA69A) : const Color(0xFF68DFB4),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editBudget(
                title: 'Overall monthly budget',
                categoryId: null,
                currentPaise: budget,
              ),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(hasBudget ? 'Edit overall budget' : 'Set overall budget'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryBudgetSummary item) {
    final hasBudget = item.budgetPaise > 0;
    final ratio = hasBudget ? item.percentageUsed : 0.0;
    final over = hasBudget && item.remainingPaise < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5EE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.category_outlined, color: _green),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasBudget
                          ? '${_money(item.expensesPaise)} of ${_money(item.budgetPaise)}'
                          : '${_money(item.expensesPaise)} spent · No limit set',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: hasBudget ? 'Edit category budget' : 'Set category budget',
                onPressed: () => _editBudget(
                  title: '${item.category.name} budget',
                  categoryId: item.category.id,
                  currentPaise: item.budgetPaise,
                ),
                icon: const Icon(Icons.edit_outlined, color: _green, size: 20),
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                backgroundColor: const Color(0xFFE9EEEC),
                color: over ? const Color(0xFFC45D58) : _green,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${(ratio * 100).toStringAsFixed(1)}% used',
                  style: TextStyle(
                    color: over ? const Color(0xFFC45D58) : _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  over
                      ? '${_money(item.remainingPaise.abs())} over'
                      : '${_money(item.remainingPaise)} left',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetAlert {
  final String title;
  final int spentPaise;
  final int budgetPaise;
  final double percentage;
  final bool exceeded;

  const _BudgetAlert({
    required this.title,
    required this.spentPaise,
    required this.budgetPaise,
    required this.percentage,
    required this.exceeded,
  });
}

class _BudgetScreenData {
  final MonthlyBudgetSummary? overall;
  final List<CategoryBudgetSummary> categories;

  const _BudgetScreenData({
    required this.overall,
    required this.categories,
  });
}


class _BudgetLimitDialog extends StatefulWidget {
  final String title;
  final String initialAmount;
  final bool canRemove;

  const _BudgetLimitDialog({
    required this.title,
    required this.initialAmount,
    required this.canRemove,
  });

  @override
  State<_BudgetLimitDialog> createState() => _BudgetLimitDialogState();
}

class _BudgetLimitDialogState extends State<_BudgetLimitDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly limit',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final amount = double.tryParse(
              (value ?? '').trim().replaceAll(',', ''),
            );
            if (amount == null || amount <= 0) {
              return 'Enter an amount greater than zero';
            }
            if (amount > 100000000000) return 'Enter a smaller amount';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.canRemove)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _BudgetDialogResult(action: _BudgetDialogAction.remove),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove budget'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _green),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _BudgetDialogResult(
                  action: _BudgetDialogAction.save,
                  amount: _controller.text,
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
