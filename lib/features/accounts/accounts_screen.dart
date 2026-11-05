
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/account_repository.dart';
import 'add_account_screen.dart';
import 'account_details_screen.dart';

const Color accountsGreen = Color(0xFF13866A);
const Color accountsNavy = Color(0xFF142B35);
const Color accountsBackground = Color(0xFFF5F7F8);

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
  late Future<List<BankAccount>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _repository = AccountRepository(widget.database);
    _loadAccounts();
  }

  void _loadAccounts() {
    _accountsFuture = _repository.getActiveAccounts();
  }

  Future<void> _refreshAccounts() async {
    setState(_loadAccounts);
    await _accountsFuture;
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

  Future<void> _openAccount(BankAccount account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailsScreen(
          database: widget.database,
          accountId: account.id,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(_loadAccounts);
    }
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
    return Scaffold(
      backgroundColor: accountsBackground,
      appBar: AppBar(
        backgroundColor: accountsBackground,
        foregroundColor: accountsNavy,
        elevation: 0,
        title: const Text(
          'My Accounts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<BankAccount>>(
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

          final accounts = snapshot.data ?? [];

          if (accounts.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: accountsGreen,
            onRefresh: _refreshAccounts,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Text(
                  '${accounts.length} active '
                  '${accounts.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ...accounts.map(_buildAccountCard),
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
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildAccountCard(BankAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: () => _openAccount(account),
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.all(19),
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
                            account.accountName,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: accountsGreen,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '•••• ${account.accountNumberLast4?.isNotEmpty == true ? account.accountNumberLast4 : '----'}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'OPENING BALANCE',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatAmount(account.openingBalancePaise),
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
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Opening date: ${_formatDate(account.openingDate)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: accountsGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
                color: Colors.black54,
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
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
