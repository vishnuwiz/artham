import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'theme/artham_theme.dart';
import 'features/transactions/activity_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/insights/insights_screen.dart';
import 'data/app_database.dart';
import 'data/alerts/alert_center.dart';
import 'data/alerts/notification_service.dart';
import 'data/backup_manager.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'data/repositories/budget_repository.dart';
import 'data/repositories/category_repository.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'widgets/animated_charts.dart';
import 'widgets/micro_interactions.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_gate.dart';
import 'features/setup/first_time_setup_gate.dart';
import 'splash/artham_splash.dart';

late final AppDatabase appDatabase;
bool _skipStartupSplashForTests = false;

/// Allows widget tests to install an in-memory database before building the app.
void initializeAppDatabaseForTesting(AppDatabase database) {
  appDatabase = database;
  _skipStartupSplashForTests = true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appDatabase = AppDatabase();

  try {
    final isConnected = await appDatabase.testConnection();

    debugPrint(
      isConnected
          ? 'Artham Database: CONNECTION SUCCESSFUL'
          : 'Artham Database: CONNECTION FAILED',
    );
  } catch (e) {
    debugPrint('Artham Database Error: $e');
  }

  // Make sure the built-in categories exist (and older ones are upgraded)
  // before any screen lists them.
  try {
    await CategoryRepository(appDatabase).ensureDefaultCategories();
  } catch (e) {
    debugPrint('Artham category setup error: $e');
  }

  runApp(const ArthamApp());
}

const Color primaryGreen = ArthamColors.lavender;
const Color darkNavy = ArthamColors.text;

class ArthamApp extends StatelessWidget {
  const ArthamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artham',
      debugShowCheckedModeBanner: false,
      theme: buildArthamTheme(),
      home: _skipStartupSplashForTests
          ? const HomeScreen()
          : SplashGate(
              child: OnboardingGate(
                child: FirstTimeSetupGate(
                  database: appDatabase,
                  child: const HomeScreen(),
                ),
              ),
            ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int selectedTab = 0;
  bool showBalance = true;
  late final BackupManagerService _backupManager = BackupManagerService(
    appDatabase,
  );
  bool _isCheckingAutomaticBackup = false;

  late Future<List<BankAccount>> _accountsFuture;
  late Future<AccountBalanceSummary> _summaryFuture;
  late Future<List<RecentTransaction>> _recentTransactionsFuture;
  late Future<MonthlyBudgetSummary?> _budgetSummaryFuture;

  // Last loaded values. They stay on screen while a refresh is in flight, so
  // returning to Home does not flash spinners or "Loading..." text.
  List<BankAccount>? _lastAccounts;
  AccountBalanceSummary? _lastSummary;
  List<RecentTransaction>? _lastRecent;
  MonthlyBudgetSummary? _lastBudget;
  bool _hasLastBudget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccounts();
    if (!_skipStartupSplashForTests) {
      unawaited(_checkScheduledBackup());
      unawaited(_startAlerts());
    }
  }

  Future<void> _startAlerts() async {
    // Tapping a notification while the app is open lands on the Alerts screen.
    NotificationService.instance.onOpenAlerts = () {
      if (mounted) unawaited(_openAlerts());
    };
    await AlertCenter.instance.start(appDatabase);
    if (!mounted) return;
    if (await NotificationService.instance.wasLaunchedByNotification()) {
      if (mounted) unawaited(_openAlerts());
    }
  }

  void _refreshAlerts() {
    if (_skipStartupSplashForTests) return;
    unawaited(AlertCenter.instance.refresh(appDatabase));
  }

  Future<void> _openAlerts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlertsScreen(database: appDatabase)),
    );
    // Reading alerts can change the unread badge.
    await AlertCenter.instance.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_loadAccounts);
      unawaited(_checkScheduledBackup());
      _refreshAlerts();
    }
  }

  @override
  void dispose() {
    NotificationService.instance.onOpenAlerts = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkScheduledBackup() async {
    if (_skipStartupSplashForTests || _isCheckingAutomaticBackup) return;
    _isCheckingAutomaticBackup = true;
    try {
      final backup = await _backupManager.maybeCreateScheduledBackup();
      if (backup != null) {
        debugPrint('Artham automatic backup saved: ${backup.path}');
      }
    } catch (error) {
      debugPrint('Artham automatic backup failed: $error');
    } finally {
      _isCheckingAutomaticBackup = false;
    }
  }

  void _loadAccounts() {
    _accountsFuture = AccountRepository(appDatabase)
        .getActiveAccounts()
        .then((value) {
          _lastAccounts = value;
          return value;
        });
    final transactionRepository = TransactionRepository(appDatabase);
    _summaryFuture = transactionRepository.getBalanceSummary().then((value) {
      _lastSummary = value;
      return value;
    });
    _recentTransactionsFuture = transactionRepository
        .getRecentTransactions(limit: 5)
        .then((value) {
          _lastRecent = value;
          return value;
        });
    _loadBudget();
  }

  void _loadBudget() {
    final repository = BudgetRepository(appDatabase);
    final now = DateTime.now();
    _budgetSummaryFuture = () async {
      await repository.applyTemplatesForMonth(now);
      final summary = await repository.getMonthlyBudgetSummary(now);
      _lastBudget = summary;
      _hasLastBudget = true;
      return summary;
    }();
  }

  void _openBudgets() {
    setState(() => selectedTab = 3);
  }

  String _currentMonthLabel() {
    const months = [
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
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<void> _openAccounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountsScreen(database: appDatabase),
      ),
    );

    if (!mounted) return;

    setState(() {
      _loadAccounts();
    });
  }

  String _formatRupees(int paise) {
    final rupees = paise / 100;
    return '₹${rupees.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      body: SafeArea(
        child: ArthamTabSwitcher(
          index: selectedTab,
          children: [
            buildDashboard(),
            ActivityScreen(database: appDatabase),
            InsightsScreen(database: appDatabase, isActive: selectedTab == 2),
            BudgetsScreen(database: appDatabase, isActive: selectedTab == 3),
            SettingsScreen(database: appDatabase),
          ],
        ),
      ),
      bottomNavigationBar: ArthamTabBar(
        selectedIndex: selectedTab,
        onSelected: (index) {
          setState(() {
            selectedTab = index;
            if (index == 0) {
              _loadAccounts();
            }
          });
          _refreshAlerts();
        },
        tabs: const [
          ArthamTab(icon: Icons.home_outlined, label: 'Home'),
          ArthamTab(icon: Icons.swap_horiz_rounded, label: 'Activity'),
          ArthamTab(icon: Icons.insights_outlined, label: 'Insights'),
          ArthamTab(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Budgets',
          ),
          ArthamTab(icon: Icons.settings_outlined, label: 'Settings'),
        ],
      ),
    );
  }

  Widget buildDashboard() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              buildHeader(),
              const SizedBox(height: 24),
              buildBalanceCard(),
              const SizedBox(height: 28),
              buildSectionTitle('My accounts', 'See all'),
              const SizedBox(height: 14),
              buildAccounts(),
              const SizedBox(height: 28),
              buildSectionTitle('Monthly budget', 'Manage'),
              const SizedBox(height: 14),
              buildBudgetCard(),
              const SizedBox(height: 28),
              buildSectionTitle('Recent transactions', 'See all'),
              const SizedBox(height: 12),
              buildTransactions(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/branding/artham_app_icon_ios_1024.png',
            height: 46,
            width: 46,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artham',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: darkNavy,
              ),
            ),
            Text(
              'Your money, under control.',
              style: TextStyle(fontSize: 12, color: ArthamColors.muted),
            ),
          ],
        ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: AlertCenter.instance.unreadCount,
          builder: (context, unread, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  key: const Key('home-alerts-button'),
                  tooltip: unread > 0 ? 'Alerts, $unread new' : 'Alerts',
                  onPressed: _openAlerts,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                if (unread > 0)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: IgnorePointer(
                      child: Container(
                        key: const Key('home-alerts-badge'),
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: ArthamColors.debit,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ArthamColors.sheet,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 21,
          backgroundColor: primaryGreen.withValues(alpha: 0.12),
          child: const Icon(Icons.person_outline, color: primaryGreen),
        ),
      ],
    );
  }

  /// A money value that counts up when it first appears (and whenever the
  /// balance is revealed again), glides to a new value when it changes, and
  /// cross-fades with its masked form when the eye icon is toggled.
  Widget _animatedMoney({
    required int? paise,
    required String placeholder,
    required String masked,
    required TextStyle style,
  }) {
    final Widget child;
    if (paise == null) {
      child = Text(
        placeholder,
        key: const ValueKey('placeholder'),
        style: style,
      );
    } else if (!showBalance) {
      child = Text(masked, key: const ValueKey('masked'), style: style);
    } else {
      child = AnimatedAmountText(
        key: const ValueKey('amount'),
        paise: paise,
        style: style,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }

  Widget buildBalanceCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 18),
          child: child,
        ),
      ),
      child: _buildBalanceCardBody(),
    );
  }

  Widget _buildBalanceCardBody() {
    return FutureBuilder<AccountBalanceSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? _lastSummary;
        final totalPlaceholder =
            snapshot.connectionState == ConnectionState.waiting
            ? 'Loading...'
            : 'Unavailable';

        return Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: ArthamColors.heroGradient,
            border: ArthamColors.glassBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'TOTAL AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() => showBalance = !showBalance);
                    },
                    icon: Icon(
                      showBalance
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              _animatedMoney(
                paise: summary?.totalBalancePaise,
                placeholder: totalPlaceholder,
                masked: '••••••••',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF62DAB0),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    snapshot.hasError
                        ? 'Unable to calculate balance'
                        : 'Calculated from your saved transactions',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: balanceSummary(
                      'INCOME THIS MONTH',
                      summary?.monthlyIncomePaise,
                      Icons.trending_up,
                      const Color(0xFF68DFB4),
                    ),
                  ),
                  Expanded(
                    child: balanceSummary(
                      'EXPENSES THIS MONTH',
                      summary?.monthlyExpensesPaise,
                      Icons.trending_down,
                      ArthamColors.debit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget balanceSummary(
    String label,
    int? amountPaise,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _animatedMoney(
          paise: amountPaise,
          placeholder: '—',
          masked: '••••',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget buildSectionTitle(String title, String action) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: darkNavy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        TextButton(
          key: title == 'Recent transactions'
              ? const ValueKey('home-recent-transactions-see-all')
              : null,
          onPressed: title == 'My accounts'
              ? _openAccounts
              : title == 'Monthly budget'
              ? _openBudgets
              : title == 'Recent transactions'
              ? () => setState(() => selectedTab = 1)
              : null,
          child: Text(
            action,
            style: const TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAccounts() {
    return FutureBuilder<List<BankAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastAccounts == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Unable to load bank accounts.',
              style: TextStyle(color: ArthamColors.debit),
            ),
          );
        }

        final accounts = snapshot.data ?? _lastAccounts ?? [];

        if (accounts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  size: 36,
                  color: primaryGreen.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No bank accounts added yet',
                  style: TextStyle(
                    color: darkNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Add your first bank account to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAccounts,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add bank account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryGreen,
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<AccountBalanceSummary>(
          future: _summaryFuture,
          builder: (context, summarySnapshot) {
            final summaryData = summarySnapshot.data ?? _lastSummary;
            if (summarySnapshot.connectionState == ConnectionState.waiting &&
                summaryData == null) {
              return const SkeletonAccountRow();
            }

            if (summaryData == null) {
              return const Text(
                'Unable to calculate account balances.',
                style: TextStyle(color: ArthamColors.debit),
              );
            }

            final balances = summaryData.accountBalancesPaise;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: accounts.map((account) {
                final balancePaise =
                    balances[account.id] ?? account.openingBalancePaise;

                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  child: PressableScale(
                    onTap: _openAccounts,
                    child: accountCard(
                      account.bankName,
                      '•••• ${account.accountNumberLast4 ?? '----'}',
                      balancePaise,
                      Icons.account_balance,
                      primaryGreen,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget accountCard(
    String name,
    String number,
    int amountPaise,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 13),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 3),
          Text(
            number,
            style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          AnimatedAmountText(
            paise: amountPaise,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: darkNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBudgetCard() {
    return FutureBuilder<MonthlyBudgetSummary?>(
      future: _budgetSummaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? (_hasLastBudget ? _lastBudget : null);

        if (snapshot.connectionState == ConnectionState.waiting &&
            !_hasLastBudget) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'Unable to load monthly budget.',
              style: TextStyle(color: ArthamColors.debit, fontSize: 12),
            ),
          );
        }

        if (summary == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentMonthLabel(),
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No monthly budget set',
                  style: TextStyle(
                    color: darkNavy,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Set a spending limit to track your monthly expenses.',
                  style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _openBudgets,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Set monthly budget'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryGreen,
                  ),
                ),
              ],
            ),
          );
        }

        final budget = summary.availableBudgetPaise;
        final expenses = summary.expensesPaise;
        final remaining = summary.remainingPaise;
        final rawProgress = summary.percentageUsed;
        final progress = rawProgress.clamp(0.0, 1.0).toDouble();
        final percentage = (rawProgress * 100).toStringAsFixed(1);
        final isOverBudget = remaining < 0;

        return Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: ArthamColors.glassGradient,
            border: ArthamColors.glassBorder,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _currentMonthLabel(),
                    style: const TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: primaryGreen,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedAmountText(
                paise: expenses,
                style: const TextStyle(
                  color: darkNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 27,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'of ${_formatRupees(budget)} available this month',
                style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
              ),
              if (summary.rolloverPaise > 0 || summary.repeatsMonthly) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (summary.rolloverPaise > 0)
                      '${_formatRupees(summary.rolloverPaise)} carried forward',
                    if (summary.repeatsMonthly) 'Repeats monthly',
                  ].join(' · '),
                  style: const TextStyle(color: primaryGreen, fontSize: 10),
                ),
              ],
              const SizedBox(height: 18),
              AnimatedProgressBar(
                value: progress,
                height: 10,
                color: isOverBudget ? ArthamColors.debit : primaryGreen,
                endColor: isOverBudget ? ArthamColors.debit : ArthamColors.mint,
                duration: const Duration(milliseconds: 1100),
                // Glow once near the limit, and shake as well when over it.
                pulse: rawProgress >= 0.8,
                shake: isOverBudget,
                pulseColor: isOverBudget
                    ? ArthamColors.debit
                    : ArthamColors.peach,
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Text(
                    isOverBudget
                        ? '$percentage% used · Over budget'
                        : '$percentage% used',
                    style: TextStyle(
                      color: isOverBudget ? ArthamColors.debit : primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      isOverBudget
                          ? '${_formatRupees(remaining.abs())} over'
                          : '${_formatRupees(remaining)} remaining',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildTransactions() {
    return FutureBuilder<List<RecentTransaction>>(
      future: _recentTransactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastRecent == null) {
          return const Padding(
            padding: EdgeInsets.all(22),
            child: Center(
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Unable to load recent transactions.',
              style: TextStyle(color: ArthamColors.debit, fontSize: 12),
            ),
          );
        }

        final recentTransactions = snapshot.data ?? _lastRecent ?? [];

        if (recentTransactions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: ArthamColors.glassGradient,
              border: ArthamColors.glassBorder,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: primaryGreen,
                  size: 34,
                ),
                SizedBox(height: 9),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: darkNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your latest transactions will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ArthamColors.muted, fontSize: 11),
                ),
              ],
            ),
          );
        }

        return Column(
          children: recentTransactions.map((item) {
            final transaction = item.transaction;
            final categoryName = item.category?.name;
            final transactionType = transaction.transactionType;
            final isIncome = transactionType == 'income';
            final isTransfer = transactionType == 'transfer';

            final title =
                item.merchant?.name ??
                (transaction.description?.trim().isNotEmpty == true
                    ? transaction.description!.trim()
                    : (categoryName ??
                          (isIncome
                              ? 'Income'
                              : isTransfer
                              ? 'Transfer'
                              : 'Expense')));

            final categoryLabel =
                categoryName ??
                (isIncome
                    ? 'Income'
                    : isTransfer
                    ? 'Transfer'
                    : 'Expense');
            final subtitle = '$categoryLabel · ${item.account.bankName}';
            final amountPrefix = isIncome ? '+' : '−';
            final amount =
                '$amountPrefix${_formatRupees(transaction.amountPaise)}';
            final icon = _transactionIcon(transactionType, categoryName);
            final accentColor = isIncome
                ? ArthamColors.mint
                : isTransfer
                ? ArthamColors.lavender
                : ArthamColors.debit;

            return transactionItem(
              title,
              subtitle,
              _formatTransactionDate(transaction.transactionDate),
              amount,
              icon,
              accentColor,
              isTransfer,
            );
          }).toList(),
        );
      },
    );
  }

  IconData _transactionIcon(String type, String? categoryName) {
    if (type == 'income') return Icons.payments_outlined;
    if (type == 'transfer') return Icons.swap_horiz_rounded;

    final category = (categoryName ?? '').toLowerCase();

    if (category.contains('food') || category.contains('dining')) {
      return Icons.restaurant_outlined;
    }
    if (category.contains('transport')) return Icons.directions_car_outlined;
    if (category.contains('shop')) return Icons.shopping_bag_outlined;
    if (category.contains('bill') || category.contains('utilit')) {
      return Icons.receipt_long_outlined;
    }
    if (category.contains('health')) return Icons.medical_services_outlined;
    if (category.contains('education')) return Icons.school_outlined;
    if (category.contains('travel')) return Icons.flight_outlined;
    if (category.contains('grocer')) return Icons.local_grocery_store_outlined;
    if (category.contains('rent')) return Icons.home_outlined;

    return Icons.payments_outlined;
  }

  String _formatTransactionDate(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final time = TimeOfDay.fromDateTime(localDate).format(context);

    if (transactionDay == today) {
      return 'Today, $time';
    }
    if (transactionDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }

    const months = [
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

    return '${localDate.day} ${months[localDate.month - 1]}, $time';
  }

  Widget transactionItem(
    String title,
    String subtitle,
    String date,
    String amount,
    IconData icon,
    Color accentColor,
    bool isTransfer,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            key: isTransfer
                ? const ValueKey('home-transfer-icon-background')
                : null,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              key: isTransfer ? const ValueKey('home-transfer-icon') : null,
              color: accentColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(
                    color: ArthamColors.faint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryGreen, size: 55),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coming soon to Artham',
            style: TextStyle(color: ArthamColors.muted),
          ),
        ],
      ),
    );
  }
}
