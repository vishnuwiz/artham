import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';

import '../../data/app_database.dart';
import '../../data/budget_forecast.dart';
import '../../data/merchant_spending_insights.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../widgets/animated_charts.dart';
import '../../widgets/micro_interactions.dart';

const Color _insightsGreen = ArthamColors.lavender;
const Color _insightsNavy = ArthamColors.text;

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
  _InsightsData? _lastData; // shown while a refresh is in flight

  // Month column currently highlighted in each bar chart (null = none).
  int? _selectedPlanMonth;
  int? _selectedFlowMonth;

  /// Wraps one month's bars so a tap highlights it and dims the others.
  Widget _selectableColumn({
    required int index,
    required int? selected,
    required ValueChanged<int?> onSelect,
    required Widget child,
  }) {
    final dimmed = selected != null && selected != index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(selected == index ? null : index),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: dimmed ? 0.35 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            alignment: Alignment.bottomCenter,
            scale: selected == index ? 1.12 : 1,
            child: child,
          ),
        ),
      ),
    );
  }

  /// A one-line readout under a chart's legend that cross-fades between months.
  Widget _chartReadout(String? text, String hint) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Align(
        key: ValueKey(text ?? hint),
        alignment: Alignment.centerLeft,
        child: Text(
          text ?? hint,
          style: TextStyle(
            color: text == null ? ArthamColors.muted : ArthamColors.text,
            fontSize: 11,
            fontWeight: text == null ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = Future.value(
      const _InsightsData(
        monthTotals: [],
        currentIncome: 0,
        currentExpenses: 0,
        categoryTotals: [],
        overallBudget: null,
        overallForecast: null,
        categoryBudgets: [],
        categoryForecasts: [],
        budgetHistory: [],
        merchantInsights: MerchantSpendingInsights(),
      ),
    );
    if (widget.isActive) {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _loadData();
    }
  }

  void _loadData() {
    _dataFuture = _fetchData().then((value) {
      _lastData = value;
      return value;
    });
  }

  Future<_InsightsData> _fetchData() async {
    final repository = TransactionRepository(widget.database);
    final budgetRepository = BudgetRepository(widget.database);
    final transactions = await repository.getAllTransactions();
    final categories = await repository.getCategories('expense');
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final merchants = await widget.database
        .select(widget.database.merchants)
        .get();
    final merchantsById = {
      for (final merchant in merchants) merchant.id: merchant,
    };
    final categoryNamesById = {
      for (final category in categories) category.id: category.name,
    };
    final merchantExpenses = <MerchantExpenseRecord>[];
    for (final transaction in transactions) {
      if (transaction.transactionType != 'expense') continue;
      final merchantId = transaction.merchantId;
      if (merchantId == null) continue;
      final merchant = merchantsById[merchantId];
      if (merchant == null) continue;
      merchantExpenses.add(
        MerchantExpenseRecord(
          merchantId: merchant.id,
          merchantName: merchant.name,
          categoryName: transaction.categoryId == null
              ? null
              : categoryNamesById[transaction.categoryId!],
          amountPaise: transaction.amountPaise,
          transactionDate: transaction.transactionDate,
        ),
      );
    }
    final merchantInsights = MerchantSpendingAnalyzer.calculate(
      expenses: merchantExpenses,
      asOf: now,
    );

    await budgetRepository.applyTemplatesForMonth(currentMonth);
    final overallBudget = await budgetRepository.getMonthlyBudgetSummary(
      currentMonth,
    );
    final categoryBudgets = await budgetRepository.getCategoryBudgetSummaries(
      currentMonth,
    );
    final budgetHistory = await budgetRepository.getMonthlyBudgetHistory(
      months: 6,
    );

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

      monthData.add(
        _MonthTotals(month: month, income: income, expenses: expenses),
      );
    }

    final currentStart = DateTime(now.year, now.month, 1);
    final nextStart = DateTime(now.year, now.month + 1, 1);
    var currentIncome = 0;
    var currentExpenses = 0;
    var expensesToDate = 0;
    final categoryTotals = <int, int>{};
    final categoryExpensesToDate = <int, int>{};

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
        // Forecasts use transactions recorded through today only. Future-dated
        // entries remain visible in existing monthly totals but do not distort
        // the current spending pace.
        if (!date.isAfter(now)) {
          expensesToDate += transaction.amountPaise;
          if (categoryId != null) {
            categoryExpensesToDate[categoryId] =
                (categoryExpensesToDate[categoryId] ?? 0) +
                transaction.amountPaise;
          }
        }
      }
    }

    final categoryData =
        categories
            .map(
              (category) => _CategoryTotal(
                name: category.name,
                amount: categoryTotals[category.id] ?? 0,
              ),
            )
            .where((item) => item.amount > 0)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    final overallForecast = overallBudget == null
        ? null
        : BudgetForecastCalculator.calculate(
            month: currentMonth,
            asOf: now,
            budgetPaise: overallBudget.availableBudgetPaise,
            spentToDatePaise: expensesToDate,
          );
    final categoryForecasts =
        categoryBudgets
            .where((item) => item.availableBudgetPaise > 0)
            .map(
              (item) => _CategoryForecast(
                name: item.category.name,
                forecast: BudgetForecastCalculator.calculate(
                  month: currentMonth,
                  asOf: now,
                  budgetPaise: item.availableBudgetPaise,
                  spentToDatePaise:
                      categoryExpensesToDate[item.category.id] ?? 0,
                ),
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                _forecastRiskRank(b.forecast.status)
                    .compareTo(_forecastRiskRank(a.forecast.status)),
          );
    return _InsightsData(
      monthTotals: monthData,
      currentIncome: currentIncome,
      currentExpenses: currentExpenses,
      categoryTotals: categoryData,
      overallBudget: overallBudget,
      overallForecast: overallForecast,
      categoryBudgets: categoryBudgets,
      categoryForecasts: categoryForecasts,
      budgetHistory: budgetHistory,
      merchantInsights: merchantInsights,
    );
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  String _monthShort(DateTime date) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[date.month - 1];
  }

  String _monthLong(DateTime date) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      body: SafeArea(
        child: FutureBuilder<_InsightsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                _lastData == null) {
              return const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: SkeletonCards(count: 4, height: 130),
              );
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load insights. Please try again.'),
              );
            }
            final data = snapshot.data ?? _lastData;
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
                          style: const TextStyle(
                            color: ArthamColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSavingsCard(data, netSavings, savingsRate),
                        const SizedBox(height: 25),
                        _sectionTitle('Budget performance', 'This month'),
                        const SizedBox(height: 12),
                        _buildBudgetPerformance(data),
                        const SizedBox(height: 25),
                        _sectionTitle(
                          'Spending forecast',
                          'Month-end estimate',
                        ),
                        const SizedBox(height: 12),
                        _buildBudgetForecast(data),
                        const SizedBox(height: 25),
                        _sectionTitle('Planned vs actual', 'Last 6 months'),
                        const SizedBox(height: 12),
                        _buildBudgetTrendChart(data.budgetHistory),
                        const SizedBox(height: 25),
                        _sectionTitle('Category budget insights', 'This month'),
                        const SizedBox(height: 12),
                        _buildCategoryBudgetInsights(data.categoryBudgets),
                        const SizedBox(height: 25),
                        _sectionTitle('Income vs expenses', 'Last 6 months'),
                        const SizedBox(height: 12),
                        _buildMonthlyChart(data.monthTotals),
                        const SizedBox(height: 25),
                        _sectionTitle('Where your money goes', 'This month'),
                        const SizedBox(height: 12),
                        _buildCategoryBreakdown(
                          data.categoryTotals,
                          data.currentExpenses,
                        ),
                        const SizedBox(height: 25),
                        _sectionTitle('Merchant spending', 'This month'),
                        const SizedBox(height: 12),
                        _buildMerchantSpending(data.merchantInsights),
                        const SizedBox(height: 25),
                        _sectionTitle(
                          'Unusual spending',
                          'Compared with recent history',
                        ),
                        const SizedBox(height: 12),
                        _buildUnusualSpend(data.merchantInsights),
                        const SizedBox(height: 20),
                        const Text(
                          'Insights are based on transactions saved in Artham. Transfers are excluded.',
                          style: TextStyle(
                            color: ArthamColors.muted,
                            fontSize: 11,
                          ),
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

  Widget _buildBudgetPerformance(_InsightsData data) {
    final overall = data.overallBudget;
    final budgetedCategories = data.categoryBudgets
        .where((item) => item.budgetPaise > 0)
        .toList();
    final overBudgetCategories = budgetedCategories
        .where((item) => item.remainingPaise < 0)
        .length;
    final onTrackCategories = budgetedCategories.length - overBudgetCategories;

    if (overall == null && budgetedCategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No budget plan for this month yet',
              style: TextStyle(
                color: _insightsNavy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Set an overall or category budget to compare your plan with actual spending.',
              style: TextStyle(color: ArthamColors.muted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final planned = overall?.availableBudgetPaise ?? 0;
    final actual = overall?.expensesPaise ?? data.currentExpenses;
    final remaining = overall?.remainingPaise ?? 0;
    final ratio = overall?.percentageUsed ?? 0.0;
    final over = overall != null && remaining < 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overall != null) ...[
            Text(
              over ? 'Overall plan exceeded' : 'Overall monthly plan',
              style: const TextStyle(
                color: _insightsNavy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _performanceMetric('PLANNED', _money(planned))),
                Expanded(child: _performanceMetric('ACTUAL', _money(actual))),
                Expanded(
                  child: _performanceMetric(
                    over ? 'OVER BY' : 'REMAINING',
                    _money(remaining.abs()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedProgressBar(
              value: ratio,
              height: 8,
              color: over ? ArthamColors.debit : _insightsGreen,
              endColor: over ? ArthamColors.debit : ArthamColors.mint,
              pulse: ratio >= 0.8,
              shake: over,
              pulseColor: over ? ArthamColors.debit : ArthamColors.peach,
            ),
            const SizedBox(height: 6),
            AnimatedPercentText(
              fraction: ratio,
              suffix:
                  ' of the available plan used'
                  '${overall.rolloverPaise > 0 ? ' · includes ${_money(overall.rolloverPaise)} carried in' : ''}',
              style: const TextStyle(color: ArthamColors.muted, fontSize: 10),
            ),
          ] else ...[
            const Text(
              'No overall monthly limit set',
              style: TextStyle(
                color: _insightsNavy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${budgetedCategories.length} category budgets cover ${_money(budgetedCategories.fold<int>(0, (sum, item) => sum + item.availableBudgetPaise))} in planned spending.',
              style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _performanceMetric(
                  'CATEGORIES ON TRACK',
                  '$onTrackCategories',
                ),
              ),
              Expanded(
                child: _performanceMetric(
                  'OVER BUDGET',
                  '$overBudgetCategories',
                ),
              ),
              Expanded(
                child: _performanceMetric(
                  'WITH A PLAN',
                  '${budgetedCategories.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetForecast(_InsightsData data) {
    final overall = data.overallForecast;
    final categories = data.categoryForecasts;
    if (overall == null && categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Set an overall or category budget to see month-end spending estimates and daily spending guidance.',
          style: TextStyle(color: ArthamColors.muted, fontSize: 11),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overall != null) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Overall spending estimate',
                    style: TextStyle(
                      color: _insightsNavy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _forecastStatusLabel(overall.status),
                  style: TextStyle(
                    color: _forecastColor(overall.status),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _performanceMetric(
                    overall.hasProjection
                        ? 'MONTH-END ESTIMATE'
                        : 'SPENT SO FAR',
                    _money(
                      overall.projectedSpendPaise ?? overall.spentToDatePaise,
                    ),
                  ),
                ),
                Expanded(
                  child: _performanceMetric(
                    'AVAILABLE PLAN',
                    _money(overall.budgetPaise),
                  ),
                ),
                Expanded(
                  child: _performanceMetric(
                    'DAYS LEFT',
                    '${overall.daysRemaining}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            AnimatedProgressBar(
              value:
                  (overall.projectedSpendPaise ?? overall.spentToDatePaise) /
                  overall.budgetPaise,
              height: 8,
              color: _forecastColor(overall.status),
            ),
            const SizedBox(height: 8),
            Text(
              _forecastMessage(overall),
              style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              _dailySpendingGuide(overall),
              style: const TextStyle(
                color: _insightsNavy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (categories.isNotEmpty) ...[
            if (overall != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],
            const Text(
              'CATEGORY OUTLOOK',
              style: TextStyle(
                color: ArthamColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < categories.length; index++) ...[
              _buildCategoryForecastTile(categories[index]),
              if (index < categories.length - 1) const Divider(height: 20),
            ],
          ],
          const SizedBox(height: 12),
          const Text(
            'Estimates use the average daily spending recorded so far this month. A projection appears after at least 3 elapsed days and can change when new transactions are recorded and Insights is refreshed.',
            style: TextStyle(color: ArthamColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryForecastTile(_CategoryForecast item) {
    final forecast = item.forecast;
    final estimate = forecast.projectedSpendPaise;
    final displayedAmount = estimate == null
        ? 'Spent ${_money(forecast.spentToDatePaise)}'
        : 'Projected ${_money(estimate)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  color: _insightsNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              _forecastStatusLabel(forecast.status),
              style: TextStyle(
                color: _forecastColor(forecast.status),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                displayedAmount,
                style: const TextStyle(
                  color: _insightsNavy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Plan ${_money(forecast.budgetPaise)}',
              style: const TextStyle(color: ArthamColors.muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 7),
        AnimatedProgressBar(
          value: (estimate ?? forecast.spentToDatePaise) / forecast.budgetPaise,
          height: 6,
          color: _forecastColor(forecast.status),
          delay: const Duration(milliseconds: 150),
        ),
        const SizedBox(height: 6),
        Text(
          _dailySpendingGuide(forecast),
          style: const TextStyle(color: ArthamColors.muted, fontSize: 10),
        ),
      ],
    );
  }

  String _forecastStatusLabel(BudgetForecastStatus status) {
    switch (status) {
      case BudgetForecastStatus.noBudget:
        return 'No budget';
      case BudgetForecastStatus.noSpending:
        return 'No spend yet';
      case BudgetForecastStatus.insufficientData:
        return 'Building trend';
      case BudgetForecastStatus.onTrack:
        return 'On track';
      case BudgetForecastStatus.approachingLimit:
        return 'Near limit';
      case BudgetForecastStatus.likelyOverBudget:
        return 'Likely over';
      case BudgetForecastStatus.alreadyOverBudget:
        return 'Over budget';
    }
  }

  Color _forecastColor(BudgetForecastStatus status) {
    switch (status) {
      case BudgetForecastStatus.alreadyOverBudget:
      case BudgetForecastStatus.likelyOverBudget:
        return ArthamColors.debit;
      case BudgetForecastStatus.approachingLimit:
        return ArthamColors.peach;
      case BudgetForecastStatus.onTrack:
        return _insightsGreen;
      case BudgetForecastStatus.noBudget:
      case BudgetForecastStatus.noSpending:
      case BudgetForecastStatus.insufficientData:
        return ArthamColors.muted;
    }
  }

  String _forecastMessage(BudgetForecast forecast) {
    switch (forecast.status) {
      case BudgetForecastStatus.noBudget:
        return 'Set a monthly limit to receive a spending forecast.';
      case BudgetForecastStatus.noSpending:
        return 'No expenses have been recorded against this plan yet.';
      case BudgetForecastStatus.insufficientData:
        return 'A month-end estimate will appear after at least 3 elapsed days.';
      case BudgetForecastStatus.onTrack:
        return 'At the current pace, estimated spending is within this month’s plan.';
      case BudgetForecastStatus.approachingLimit:
        return 'At the current pace, estimated spending may use 90% or more of the available plan.';
      case BudgetForecastStatus.likelyOverBudget:
        return 'At the current pace, spending may exceed the available plan by ${_money(forecast.projectedOverBudgetPaise)}.';
      case BudgetForecastStatus.alreadyOverBudget:
        return 'Recorded spending has already exceeded the available plan by ${_money(forecast.alreadyOverBudgetPaise)}.';
    }
  }

  String _dailySpendingGuide(BudgetForecast forecast) {
    final daily = forecast.recommendedDailySpendPaise;
    if (daily == null) return 'No daily guide until a monthly plan is set.';
    if (forecast.remainingBudgetPaise <= 0) {
      return 'Daily guide: no budget remains for additional spending.';
    }
    return 'Daily guide: about ${_money(daily)} per day through month-end, including today.';
  }

  Widget _performanceMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ArthamColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _insightsNavy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetTrendChart(List<MonthlyBudgetHistoryItem> months) {
    final maxValue = months.fold<int>(0, (max, item) {
      final value = item.availableBudgetPaise > item.expensesPaise
          ? item.availableBudgetPaise
          : item.expensesPaise;
      return value > max ? value : max;
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 14),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _legend(_insightsGreen, 'Planned'),
              const SizedBox(width: 18),
              _legend(ArthamColors.debit, 'Actual'),
            ],
          ),
          const SizedBox(height: 10),
          _chartReadout(
            _selectedPlanMonth != null && _selectedPlanMonth! < months.length
                ? '${_monthShort(months[_selectedPlanMonth!].month)} · '
                      'Planned ${months[_selectedPlanMonth!].hasBudget ? _money(months[_selectedPlanMonth!].availableBudgetPaise) : 'not set'} · '
                      'Actual ${_money(months[_selectedPlanMonth!].expensesPaise)}'
                : null,
            'Tap a month for exact amounts',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 145,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.indexed.map((entry) {
                final index = entry.$1;
                final item = entry.$2;
                final delay = Duration(milliseconds: 90 * index);
                final planHeight = maxValue == 0 || !item.hasBudget
                    ? 0.0
                    : 100 * item.availableBudgetPaise / maxValue;
                final actualHeight = maxValue == 0
                    ? 0.0
                    : 100 * item.expensesPaise / maxValue;
                return _selectableColumn(
                  index: index,
                  selected: _selectedPlanMonth,
                  onSelect: (value) =>
                      setState(() => _selectedPlanMonth = value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(planHeight, color: _insightsGreen, delay: delay),
                            const SizedBox(width: 3),
                            _bar(
                              actualHeight,
                              color: ArthamColors.debit,
                              delay: delay + const Duration(milliseconds: 60),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _monthShort(item.month),
                        style: const TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Months without an overall budget show actual spending only.',
              style: TextStyle(color: ArthamColors.muted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetInsights(List<CategoryBudgetSummary> categories) {
    final items =
        categories
            .where((item) => item.budgetPaise > 0 || item.expensesPaise > 0)
            .toList()
          ..sort((a, b) {
            final aOver = a.budgetPaise > 0 && a.remainingPaise < 0;
            final bOver = b.budgetPaise > 0 && b.remainingPaise < 0;
            if (aOver != bOver) return aOver ? -1 : 1;
            if (a.budgetPaise == 0 && b.budgetPaise == 0) {
              return b.expensesPaise.compareTo(a.expensesPaise);
            }
            if (a.budgetPaise == 0) return 1;
            if (b.budgetPaise == 0) return -1;
            return b.percentageUsed.compareTo(a.percentageUsed);
          });

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Category budget comparisons will appear once you set category limits and record spending.',
          style: TextStyle(color: ArthamColors.muted, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: items.indexed.map((entry) {
          final itemIndex = entry.$1;
          final item = entry.$2;
          final hasBudget = item.budgetPaise > 0;
          final over = hasBudget && item.remainingPaise < 0;
          final ratio = hasBudget ? item.percentageUsed : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category.name,
                        style: const TextStyle(
                          color: _insightsNavy,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      hasBudget
                          ? (over
                                ? '${_money(item.remainingPaise.abs())} over'
                                : '${_money(item.remainingPaise)} left')
                          : 'No plan',
                      style: TextStyle(
                        color: over ? ArthamColors.debit : ArthamColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasBudget
                      ? 'Actual ${_money(item.expensesPaise)} · Plan ${_money(item.availableBudgetPaise)}'
                      : 'Actual spending ${_money(item.expensesPaise)}',
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                  ),
                ),
                if (hasBudget) ...[
                  const SizedBox(height: 7),
                  AnimatedProgressBar(
                    value: ratio,
                    height: 6,
                    color: over ? ArthamColors.debit : _insightsGreen,
                    endColor: over ? ArthamColors.debit : ArthamColors.mint,
                    delay: Duration(milliseconds: 80 * itemIndex),
                    pulse: ratio >= 0.8,
                    shake: over,
                    pulseColor: over ? ArthamColors.debit : ArthamColors.peach,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedPercentText(
                      fraction: ratio,
                      suffix: ' used',
                      style: TextStyle(
                        color: over ? ArthamColors.debit : _insightsGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _insightsNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: _insightsGreen,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsCard(
    _InsightsData data,
    int netSavings,
    double savingsRate,
  ) {
    final positive = netSavings >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: ArthamColors.heroGradient,
        border: ArthamColors.glassBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NET SAVINGS THIS MONTH',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    AnimatedAmountText(
                      paise: netSavings.abs(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      positive
                          ? 'You are spending within your income'
                          : 'Expenses exceed income',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedRing(value: savingsRate),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _whiteMetric('INCOME', _money(data.currentIncome)),
              ),
              Expanded(
                child: _whiteMetric('EXPENSES', _money(data.currentExpenses)),
              ),
              Expanded(
                child: _whiteMetric(
                  'SAVINGS RATE',
                  '${(savingsRate * 100).toStringAsFixed(1)}%',
                ),
              ),
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
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(List<_MonthTotals> months) {
    final maxValue = months.fold<int>(0, (max, item) {
      final monthMax = item.income > item.expenses
          ? item.income
          : item.expenses;
      return monthMax > max ? monthMax : max;
    });
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _legend(ArthamColors.lavender, 'Income'),
              const SizedBox(width: 18),
              _legend(ArthamColors.debit, 'Expenses'),
            ],
          ),
          const SizedBox(height: 10),
          _chartReadout(
            _selectedFlowMonth != null && _selectedFlowMonth! < months.length
                ? '${_monthShort(months[_selectedFlowMonth!].month)} · '
                      'Income ${_money(months[_selectedFlowMonth!].income)} · '
                      'Expenses ${_money(months[_selectedFlowMonth!].expenses)}'
                : null,
            'Tap a month for exact amounts',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.indexed.map((entry) {
                final delay = Duration(milliseconds: 90 * entry.$1);
                final item = entry.$2;
                final incomeHeight = maxValue == 0
                    ? 0.0
                    : 105 * item.income / maxValue;
                final expenseHeight = maxValue == 0
                    ? 0.0
                    : 105 * item.expenses / maxValue;
                return _selectableColumn(
                  index: entry.$1,
                  selected: _selectedFlowMonth,
                  onSelect: (value) =>
                      setState(() => _selectedFlowMonth = value),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _bar(incomeHeight, delay: delay),
                            const SizedBox(width: 4),
                            _bar(
                              expenseHeight,
                              color: ArthamColors.debit,
                              delay: delay + const Duration(milliseconds: 60),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _monthShort(item.month),
                        style: const TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 10,
                        ),
                      ),
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

  Widget _bar(
    double height, {
    Color color = _insightsGreen,
    Duration delay = Duration.zero,
  }) {
    return AnimatedBar(height: height, color: color, delay: delay);
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildMerchantSpending(MerchantSpendingInsights insights) {
    final items = insights.topMerchants;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Merchant spending insights will appear for recognised merchants.',
          style: TextStyle(color: ArthamColors.muted, fontSize: 11),
        ),
      );
    }

    final largestSpend = items.first.currentMonthSpendPaise;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: items.indexed.map((entry) {
          final rowIndex = entry.$1;
          final item = entry.$2;
          final share = largestSpend > 0
              ? item.currentMonthSpendPaise / largestSpend
              : 0.0;
          final countLabel = item.currentMonthTransactionCount == 1
              ? '1 transaction'
              : '${item.currentMonthTransactionCount} transactions';
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.merchantName,
                        style: const TextStyle(
                          color: _insightsNavy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _money(item.currentMonthSpendPaise),
                      style: const TextStyle(
                        color: _insightsNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.categoryName ?? 'Uncategorised'} · $countLabel',
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedProgressBar(
                  value: share,
                  height: 7,
                  color: _insightsGreen,
                  endColor: ArthamColors.mint,
                  delay: Duration(milliseconds: 80 * rowIndex),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnusualSpend(MerchantSpendingInsights insights) {
    final items = insights.unusualMerchants;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: _insightsGreen,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No unusual merchant spend flagged',
                    style: TextStyle(
                      color: _insightsNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 7),
            Text(
              'Flags appear after at least three prior payment dates across two months, when spending is more than 50% and ₹500 above the usual amount by this date.',
              style: TextStyle(color: ArthamColors.muted, fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.merchantName,
                        style: const TextStyle(
                          color: _insightsNavy,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: ArthamColors.debitTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${item.percentageAboveUsual}% above usual',
                        style: const TextStyle(
                          color: ArthamColors.debit,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.categoryName ?? 'Uncategorised'} · ${item.currentMonthTransactionCount} current-month payments',
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Spent ${_money(item.currentMonthSpendPaise)} · Usual by today ${_money(item.expectedSpendToDatePaise)}',
                  style: const TextStyle(
                    color: ArthamColors.debit,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<_CategoryTotal> categories, int total) {
    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: ArthamColors.glassGradient,
          border: ArthamColors.glassBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              color: _insightsGreen,
              size: 34,
            ),
            SizedBox(height: 8),
            Text(
              'No expenses recorded this month',
              style: TextStyle(
                color: _insightsNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Your category breakdown will appear here.',
              style: TextStyle(color: ArthamColors.muted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          AnimatedDonutChart(
            slices: _pieSlices(categories),
            centerLabel: 'Spent',
            formatValue: (value) => _money(value.round()),
            // The rows below already list every category with its colour.
            showLegend: false,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...categories.indexed.map((entry) {
          final index = entry.$1;
          final item = entry.$2;
          final share = total > 0 ? item.amount / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: _insightsNavy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _money(item.amount),
                      style: const TextStyle(
                        color: _insightsNavy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedProgressBar(
                  value: share,
                  height: 7,
                  // Matches the pie: categories past the sixth are "Other".
                  color: categories.length > 7 && index >= 6
                      ? ArthamChartPalette.other
                      : ArthamChartPalette.at(index),
                  delay: Duration(milliseconds: 80 * index),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedPercentText(
                    fraction: share,
                    style: const TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
          }),
        ],
      ),
    );
  }

  /// Largest categories get their own slice; the rest are grouped as "Other"
  /// so the pie stays readable.
  List<DonutSlice> _pieSlices(List<_CategoryTotal> categories) {
    const maxSlices = 6;
    final slices = <DonutSlice>[];
    final head = categories.length > maxSlices + 1
        ? categories.take(maxSlices).toList()
        : categories;
    for (var i = 0; i < head.length; i++) {
      slices.add(
        DonutSlice(
          label: head[i].name,
          value: head[i].amount.toDouble(),
          color: ArthamChartPalette.at(i),
        ),
      );
    }
    if (head.length < categories.length) {
      final rest = categories
          .skip(head.length)
          .fold<int>(0, (sum, item) => sum + item.amount);
      slices.add(
        DonutSlice(
          label: 'Other',
          value: rest.toDouble(),
          color: ArthamChartPalette.other,
        ),
      );
    }
    return slices;
  }
}

class _InsightsData {
  final List<_MonthTotals> monthTotals;
  final int currentIncome;
  final int currentExpenses;
  final List<_CategoryTotal> categoryTotals;
  final MonthlyBudgetSummary? overallBudget;
  final BudgetForecast? overallForecast;
  final List<CategoryBudgetSummary> categoryBudgets;
  final List<_CategoryForecast> categoryForecasts;
  final List<MonthlyBudgetHistoryItem> budgetHistory;
  final MerchantSpendingInsights merchantInsights;

  const _InsightsData({
    required this.monthTotals,
    required this.currentIncome,
    required this.currentExpenses,
    required this.categoryTotals,
    required this.overallBudget,
    required this.overallForecast,
    required this.categoryBudgets,
    required this.categoryForecasts,
    required this.budgetHistory,
    required this.merchantInsights,
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

class _CategoryForecast {
  final String name;
  final BudgetForecast forecast;

  const _CategoryForecast({required this.name, required this.forecast});
}

int _forecastRiskRank(BudgetForecastStatus status) {
  switch (status) {
    case BudgetForecastStatus.alreadyOverBudget:
      return 6;
    case BudgetForecastStatus.likelyOverBudget:
      return 5;
    case BudgetForecastStatus.approachingLimit:
      return 4;
    case BudgetForecastStatus.onTrack:
      return 3;
    case BudgetForecastStatus.insufficientData:
      return 2;
    case BudgetForecastStatus.noSpending:
      return 1;
    case BudgetForecastStatus.noBudget:
      return 0;
  }
}
