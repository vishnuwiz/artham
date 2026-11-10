
import 'package:flutter/material.dart';
import '../../theme/artham_theme.dart';

import '../../data/app_database.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import 'add_account_screen.dart';
import 'transfer_money_screen.dart';
import 'account_history_screen.dart';

const Color accountsGreen = ArthamColors.lavender;
const Color accountsNavy = ArthamColors.text;
const Color accountsBackground = Colors.transparent;

class AccountsScreen extends StatefulWidget {
  final AppDatabase database;

  const AccountsScreen({
    super.key,
    required this.database,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final AccountRepository _repository;
  late Future<_AccountsData> _accountsFuture;
  late final TransactionRepository _transactionRepository;

  @override
  void initState() {
    super.initState();
    _repository = AccountRepository(widget.database);
    _transactionRepository = TransactionRepository(widget.database);
    _loadAccounts();
  }

  void _loadAccounts() {
    _accountsFuture = _fetchAccounts();
  }

  Future<_AccountsData> _fetchAccounts() async {
    final accounts = await _repository.getActiveAccounts();
    final balances = await _transactionRepository.getBalanceSummary();
    return _AccountsData(accounts: accounts, balances: balances.accountBalancesPaise,
        totalBalancePaise: balances.totalBalancePaise);
  }

  Future<void> _openTransfer() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransferMoneyScreen(database: widget.database)),
    );
    if (result == true && mounted) setState(_loadAccounts);
  }

  Future<void> _addAccount() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountScreen(
          database: widget.database,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(_loadAccounts);
    }
  }

  Future<void> _editAccount(BankAccount account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountScreen(
          database: widget.database,
          account: account,
        ),
      ),
    );
    if (result == true && mounted) setState(_loadAccounts);
  }

  String _formatAmount(int paise) {
    return '₹${(paise / 100).toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: accountsNavy,
        elevation: 0,
        title: const Text(
          'My Accounts',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<_AccountsData>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: accountsGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load accounts: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final accounts = data.accounts;

          if (accounts.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: accountsGreen,
            onRefresh: () async {
              setState(_loadAccounts);
              await _accountsFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Text(
                  '${accounts.length} active '
                  '${accounts.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: ArthamColors.heroGradient,
                    border: ArthamColors.glassBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL ACCOUNT BALANCE',
                        style: TextStyle(color: Colors.white70, fontSize: 10,
                          letterSpacing: 1, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Text(_formatAmount(data.totalBalancePaise),
                        style: const TextStyle(color: Colors.white,
                          fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _openTransfer,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Transfer between accounts'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...accounts.map((account) => _buildAccountCard(
                  account, data.balances[account.id] ?? account.openingBalancePaise)),

                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _addAccount,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add another account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accountsGreen,
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: accountsGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        backgroundColor: accountsGreen,
        foregroundColor: ArthamColors.onAccent,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildAccountCard(BankAccount account, int currentBalancePaise) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountHistoryScreen(
              database: widget.database,
              account: account,
            ),
          ),
        ).then((_) {
          if (mounted) setState(_loadAccounts);
        });
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: accountsGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: accountsGreen,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName,
                      style: const TextStyle(
                        color: accountsNavy,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountNumberLastFourLabel(account.accountNumberLast4),
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Account options',
                onSelected: (value) {
                  if (value == 'edit') _editAccount(account);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 10),
                        Text('Edit account'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: accountsNavy),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'CURRENT BALANCE',
            style: TextStyle(
              color: ArthamColors.muted,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _formatAmount(currentBalancePaise),
            style: const TextStyle(
              color: accountsNavy,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: ArthamColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Opening date: ${_formatDate(account.openingDate)}',
                style: const TextStyle(
                  color: ArthamColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 65,
              color: accountsGreen,
            ),
            const SizedBox(height: 18),
            const Text(
              'No bank accounts yet',
              style: TextStyle(
                color: accountsNavy,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first bank account to start '
              'managing your finances.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ArthamColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Bank Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accountsGreen,
                foregroundColor: ArthamColors.onAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AccountsData {
  final List<BankAccount> accounts;
  final Map<int, int> balances;
  final int totalBalancePaise;

  const _AccountsData({
    required this.accounts,
    required this.balances,
    required this.totalBalancePaise,
  });
}
