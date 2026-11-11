import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../theme/artham_theme.dart';
import '../accounts/add_account_screen.dart';

/// Optional first-run setup. Reuses Artham's existing bank-account form.
class FirstTimeSetupScreen extends StatefulWidget {
  const FirstTimeSetupScreen({
    super.key,
    required this.database,
    required this.onFinish,
  });

  final AppDatabase database;
  final Future<void> Function() onFinish;

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  late final AccountRepository _accounts =
      AccountRepository(widget.database);
  late final TransactionRepository _transactions =
      TransactionRepository(widget.database);
  late Future<List<BankAccount>> _accountsFuture =
      _accounts.getActiveAccounts();

  List<Category> _expenses = [];
  List<Category> _income = [];
  int _step = 0;
  bool _busy = false;

  Future<void> _addAccount() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountScreen(database: widget.database),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _accountsFuture = _accounts.getActiveAccounts());
    }
  }

  Future<void> _loadCategories() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _transactions.seedDefaultCategories();
      final expenses = await _transactions.getCategories('expense');
      final income = await _transactions.getCategories('income');
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _income = income;
        _step = 1;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to prepare categories: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 0) {
      await _loadCategories();
    } else if (_step == 1) {
      setState(() => _step = 2);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onFinish();
  }

  void _back() {
    if (_step > 0 && !_busy) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Account', 'Categories', 'Ready'];
    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Set up Artham',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Skip'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'STEP \${_step + 1} OF 3',
                        style: const TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        labels[_step],
                        style: const TextStyle(
                          color: ArthamColors.lavender,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / 3,
                      minHeight: 5,
                      backgroundColor: ArthamColors.line,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == 0
                    ? _accountStep()
                    : _step == 1
                        ? _categoriesStep()
                        : _readyStep(),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton.icon(
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy ? null : _next,
                    icon: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ArthamColors.onAccent,
                            ),
                          )
                        : Icon(
                            _step == 2
                                ? Icons.dashboard_outlined
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      _busy
                          ? 'Please wait...'
                          : _step == 2
                              ? 'Go to dashboard'
                              : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountStep() {
    return ListView(
      key: const ValueKey('setup-account'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        const Text(
          'YOUR MONEY, IN ONE PLACE',
          style: TextStyle(
            color: ArthamColors.lavender,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Bring your accounts together.',
          style: TextStyle(
            color: ArthamColors.text,
            fontSize: 27,
            height: 1.13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Add a bank account to see your available balance and organise '
          'your transactions in Artham.',
          style: TextStyle(
            color: ArthamColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: FutureBuilder<List<BankAccount>>(
            future: _accountsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Unable to load accounts: \${snapshot.error}',
                  style: const TextStyle(color: ArthamColors.debit),
                );
              }
              final accounts = snapshot.data ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BANK ACCOUNTS',
                    style: TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (accounts.isEmpty)
                    const Text(
                      'No accounts added yet. You can add one now or skip '
                      'and do it later.',
                      style: TextStyle(color: ArthamColors.muted),
                    )
                  else
                    for (final account in accounts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.account_balance_outlined,
                          color: ArthamColors.lavender,
                        ),
                        title: Text(account.bankName),
                        subtitle: Text(
                          accountNumberLastFourLabel(
                            account.accountNumberLast4,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.check_circle_rounded,
                          color: ArthamColors.mint,
                        ),
                      ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addAccount,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        accounts.isEmpty
                            ? 'Add bank account'
                            : 'Add another account',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Only the bank name, last four digits and opening balance are '
          'needed. Never enter your PIN, CVV or banking password.',
          style: TextStyle(
            color: ArthamColors.faint,
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _categoriesStep() {
    return ListView(
      key: const ValueKey('setup-categories'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        const Text(
          'A CLEARER VIEW OF EVERY RUPEE',
          style: TextStyle(
            color: ArthamColors.lavender,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Start with useful categories.',
          style: TextStyle(
            color: ArthamColors.text,
            fontSize: 27,
            height: 1.13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Artham has prepared starter categories for your income and '
          'expenses. You can change the category whenever you record a '
          'transaction.',
          style: TextStyle(
            color: ArthamColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _categoryPanel('EXPENSE CATEGORIES', _expenses, ArthamColors.peach),
        const SizedBox(height: 14),
        _categoryPanel('INCOME CATEGORIES', _income, ArthamColors.mint),
        const SizedBox(height: 12),
        const Text(
          'These categories are saved locally on your device.',
          style: TextStyle(color: ArthamColors.faint, fontSize: 11),
        ),
      ],
    );
  }

  Widget _categoryPanel(String title, List<Category> items, Color accent) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                '\${items.length}',
                style: const TextStyle(color: ArthamColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items
                .map(
                  (item) => Chip(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: accent.withValues(alpha: 0.25)),
                    label: Text(item.name),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _readyStep() {
    return ListView(
      key: const ValueKey('setup-ready'),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
      children: [
        const CircleAvatar(
          radius: 42,
          backgroundColor: ArthamColors.mintTint,
          child: Icon(
            Icons.check_rounded,
            color: ArthamColors.mint,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "You're all set.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ArthamColors.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your Artham workspace is ready. Start adding transactions and '
          'let your financial picture take shape.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ArthamColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _summaryRow(
                Icons.account_balance_outlined,
                'Bank accounts',
                'Manage accounts from Home',
              ),
              const Divider(height: 22),
              _summaryRow(
                Icons.category_outlined,
                'Starter categories',
                '\${_expenses.length} expenses · \${_income.length} income',
              ),
              const Divider(height: 22),
              _summaryRow(
                Icons.phonelink_lock_outlined,
                'Private by design',
                'Your data stays on this device',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<BankAccount>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.data?.isNotEmpty ?? false) {
              return const SizedBox.shrink();
            }
            return const Text(
              'No account added yet? That is okay. You can add one later '
              'from Home → My accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ArthamColors.faint,
                fontSize: 11,
                height: 1.45,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String title, String detail) {
    return Row(
      children: [
        Icon(icon, color: ArthamColors.lavender, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ArthamColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  color: ArthamColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
