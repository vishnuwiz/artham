
import 'package:flutter/material.dart';
import 'features/transactions/activity_screen.dart';
import 'data/app_database.dart';
import 'data/repositories/account_repository.dart';
import 'features/accounts/accounts_screen.dart';

late final AppDatabase appDatabase;

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

  runApp(const ArthamApp());
}

const Color primaryGreen = Color(0xFF13866A);
const Color darkNavy = Color(0xFF142B35);
const Color pageBackground = Color(0xFFF5F7F8);

class ArthamApp extends StatelessWidget {
  const ArthamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artham',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  bool showBalance = true;

  late Future<List<BankAccount>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  void _loadAccounts() {
    _accountsFuture = AccountRepository(appDatabase).getActiveAccounts();
  }

  Future<void> _openAccounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountsScreen(
          database: appDatabase,
        ),
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
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            buildDashboard(),
            ActivityScreen(database: appDatabase),
            buildPlaceholder('Insights', Icons.insights),
            buildPlaceholder('Budgets', Icons.pie_chart),
            buildPlaceholder('Settings', Icons.settings),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: primaryGreen.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
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
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: darkNavy,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Color(0xFF55D8AD),
            size: 25,
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
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
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

  Widget buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: darkNavy,
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [Color(0xFF142B35), Color(0xFF176B59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          Text(
            showBalance ? '₹81,250.00' : '••••••••',
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
                'Sample data · Not connected to banks',
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
                  '₹55,000',
                  Icons.trending_up,
                  const Color(0xFF68DFB4),
                ),
              ),
              Expanded(
                child: balanceSummary(
                  'EXPENSES THIS MONTH',
                  '₹23,750',
                  Icons.trending_down,
                  const Color(0xFFFFA69A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget balanceSummary(
    String label,
    String amount,
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
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          amount,
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
          onPressed: title == 'My accounts' ? _openAccounts : () {},
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
        if (snapshot.connectionState == ConnectionState.waiting) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Unable to load bank accounts.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final accounts = snapshot.data ?? [];

        if (accounts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
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

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: accounts.map((account) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              child: accountCard(
                account.bankName,
                '•••• ${account.accountNumberLast4 ?? '----'}',
                _formatRupees(account.openingBalancePaise),
                Icons.account_balance,
                primaryGreen,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget accountCard(
    String name,
    String number,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            number,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            amount,
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
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'November 2026',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              Spacer(),
              Icon(
                Icons.calendar_month_outlined,
                color: primaryGreen,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '₹23,750',
            style: TextStyle(
              color: darkNavy,
              fontWeight: FontWeight.w800,
              fontSize: 27,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'of ₹35,000 monthly budget',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(
              value: 23750 / 35000,
              minHeight: 10,
              backgroundColor: Color(0xFFE9EEEC),
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 13),
          const Row(
            children: [
              Text(
                '67.9% used',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Spacer(),
              Text(
                '₹11,250 remaining',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTransactions() {
    return Column(
      children: [
        transactionItem(
          'Swiggy',
          'Food & Dining · Federal Bank',
          'Today, 12:30 PM',
          '−₹450',
          Icons.restaurant,
          const Color(0xFFEAF3E9),
          false,
        ),
        transactionItem(
          'Petrol Pump',
          'Transportation · HDFC Bank',
          'Today, 10:15 AM',
          '−₹1,000',
          Icons.local_gas_station,
          const Color(0xFFEAF0FC),
          false,
        ),
        transactionItem(
          'Salary Credit',
          'Income · Federal Bank',
          '1 Nov, 09:00 AM',
          '+₹35,000',
          Icons.payments_outlined,
          const Color(0xFFE5F5EE),
          true,
        ),
      ],
    );
  }

  Widget transactionItem(
    String title,
    String subtitle,
    String date,
    String amount,
    IconData icon,
    Color background,
    bool isIncome,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryGreen, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isIncome ? primaryGreen : const Color(0xFFC45D58),
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
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
