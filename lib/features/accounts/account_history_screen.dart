import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

const Color historyGreen = ArthamColors.lavender;
const Color historyNavy = ArthamColors.text;
const Color historyBackground = Colors.transparent;

class AccountHistoryScreen extends StatefulWidget {
  final AppDatabase database;
  final BankAccount account;

  const AccountHistoryScreen({
    super.key,
    required this.database,
    required this.account,
  });

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  late final TransactionRepository _repository;
  late Future<_HistoryData> _future;

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _future = _load();
  }

  Future<_HistoryData> _load() async {
    final summary = await _repository.getBalanceSummary();
    final transactions = await _repository.getAccountTransactions(
      widget.account.id,
    );
    final categories = await widget.database
        .select(widget.database.categories)
        .get();
    return _HistoryData(
      balance:
          summary.accountBalancesPaise[widget.account.id] ??
          widget.account.openingBalancePaise,
      transactions: transactions,
      categories: {for (final c in categories) c.id: c.name},
    );
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';
  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Account History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: historyNavy,
        elevation: 0,
      ),
      body: FutureBuilder<_HistoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: historyGreen),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load history: ${snapshot.error}'),
            );
          }
          final data = snapshot.data!;
          int income = 0;
          int expenses = 0;
          for (final tx in data.transactions) {
            if (tx.transactionType == 'income') income += tx.amountPaise;
            if (tx.transactionType == 'expense') expenses += tx.amountPaise;
          }
          return RefreshIndicator(
            color: historyGreen,
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: ArthamColors.heroGradient,
                    border: ArthamColors.glassBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.account.bankName,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        accountNumberLastFourLabel(
                          widget.account.accountNumberLast4,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'CURRENT BALANCE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        _money(data.balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _summary(
                              'Income',
                              income,
                              const Color(0xFF78E0B9),
                            ),
                          ),
                          Expanded(
                            child: _summary(
                              'Expenses',
                              expenses,
                              ArthamColors.debit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        color: historyNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${data.transactions.length} records',
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (data.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No transactions for this account yet.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...data.transactions.map((tx) {
                    final isIncomingTransfer =
                        tx.transactionType == 'transfer' &&
                        tx.transferToAccountId == widget.account.id;
                    final isTransfer = tx.transactionType == 'transfer';
                    final isIncome =
                        tx.transactionType == 'income' || isIncomingTransfer;
                    final title = isTransfer
                        ? (isIncomingTransfer
                              ? 'Transfer received'
                              : 'Transfer sent')
                        : ((tx.categoryId == null
                                  ? null
                                  : data.categories[tx.categoryId!]) ??
                              tx.description ??
                              tx.transactionType);
                    final color = isIncome ? historyGreen : ArthamColors.debit;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: ArthamColors.glassGradient,
                        border: ArthamColors.glassBorder,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isTransfer
                                ? Icons.swap_horiz_rounded
                                : (isIncome
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded),
                            color: color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: historyNavy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _date(tx.transactionDate),
                                  style: const TextStyle(
                                    color: ArthamColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isIncome ? '+' : '−'}${_money(tx.amountPaise)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(String label, int amount, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 5),
      Text(
        _money(amount),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _HistoryData {
  final int balance;
  final List<MoneyTransaction> transactions;
  final Map<int, String> categories;
  const _HistoryData({
    required this.balance,
    required this.transactions,
    required this.categories,
  });
}
