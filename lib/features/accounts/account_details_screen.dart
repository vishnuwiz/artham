
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/repositories/account_repository.dart';

const Color detailsGreen = Color(0xFF13866A);
const Color detailsNavy = Color(0xFF142B35);
const Color detailsBackground = Color(0xFFF5F7F8);

class AccountDetailsScreen extends StatefulWidget {
  final AppDatabase database;
  final int accountId;

  const AccountDetailsScreen({
    super.key,
    required this.database,
    required this.accountId,
  });

  @override
  State<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late final AccountRepository _repository;
  late Future<BankAccount?> _accountFuture;

  @override
  void initState() {
    super.initState();
    _repository = AccountRepository(widget.database);
    _loadAccount();
  }

  void _loadAccount() {
    _accountFuture = _repository.getAccountById(widget.accountId);
  }

  String _formatAmount(int paise) {
    return '₹${(paise / 100).toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _editAccount(BankAccount account) async {
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => EditAccountScreen(
        database: widget.database,
        account: account,
      ),
    ),
  );

  if (result == true && mounted) {
    // Notify My Accounts that the account has changed.
    Navigator.pop(context, true);
  }
}

  Future<void> _deactivateAccount(BankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Text(
          'Are you sure you want to deactivate '
          '${account.bankName} (${account.accountName})?\n\n'
          'The account will be hidden from your active accounts. '
          'Its saved information and transaction history will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final success =
          await _repository.deactivateAccount(account.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deactivated')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account could not be deactivated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _detailRow(String label, String value, {bool prominent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: detailsNavy,
                fontSize: prominent ? 17 : 14,
                fontWeight: prominent ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: detailsBackground,
      appBar: AppBar(
        backgroundColor: detailsBackground,
        foregroundColor: detailsNavy,
        elevation: 0,
        title: const Text(
          'Account Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<BankAccount?>(
        future: _accountFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: detailsGreen),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Unable to load account: ${snapshot.error}'));
          }

          final account = snapshot.data;

          if (account == null) {
            return const Center(child: Text('Account not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 65,
                      width: 65,
                      decoration: BoxDecoration(
                        color: detailsGreen.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: detailsGreen,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      account.bankName,
                      style: const TextStyle(
                        color: detailsNavy,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      account.accountName,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'OPENING BALANCE',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _formatAmount(account.openingBalancePaise),
                      style: const TextStyle(
                        color: detailsNavy,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'This is the recorded opening balance, not the live bank balance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _detailRow('Bank name', account.bankName),
                    const Divider(height: 1),
                    _detailRow('Account name', account.accountName),
                    const Divider(height: 1),
                    _detailRow(
                      'Account number',
                      '•••• ${account.accountNumberLast4?.isNotEmpty == true ? account.accountNumberLast4 : '----'}',
                    ),
                    const Divider(height: 1),
                    _detailRow(
                      'Opening balance',
                      _formatAmount(account.openingBalancePaise),
                      prominent: true,
                    ),
                    const Divider(height: 1),
                    _detailRow(
                      'Opening date',
                      _formatDate(account.openingDate),
                    ),
                    const Divider(height: 1),
                    _detailRow(
                      'Account status',
                      account.isActive ? 'Active' : 'Inactive',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _editAccount(account),
                  style: FilledButton.styleFrom(
                    backgroundColor: detailsGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit account'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: account.isActive
                    ? () => _deactivateAccount(account)
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Deactivate account'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class EditAccountScreen extends StatefulWidget {
  final AppDatabase database;
  final BankAccount account;

  const EditAccountScreen({
    super.key,
    required this.database,
    required this.account,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late final AccountRepository _repository;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _last4Controller;
  late final TextEditingController _balanceController;

  late DateTime _openingDate;
  bool _isSaving = false;

  final List<String> _banks = [
    'Federal Bank',
    'HDFC Bank',
    'State Bank of India',
    'ICICI Bank',
    'Axis Bank',
    'South Indian Bank',
    'Canara Bank',
    'Bank of Baroda',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _repository = AccountRepository(widget.database);
    _bankNameController =
        TextEditingController(text: widget.account.bankName);
    _accountNameController =
        TextEditingController(text: widget.account.accountName);
    _last4Controller = TextEditingController(
      text: widget.account.accountNumberLast4 ?? '',
    );
    _balanceController = TextEditingController(
      text: (widget.account.openingBalancePaise / 100).toStringAsFixed(2),
    );
    _openingDate = widget.account.openingDate;
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNameController.dispose();
    _last4Controller.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() => _openingDate = selected);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final balance =
          double.parse(_balanceController.text.trim());

      final success = await _repository.updateAccount(
        accountId: widget.account.id,
        bankName: _bankNameController.text.trim(),
        accountName: _accountNameController.text.trim(),
        accountNumberLast4: _last4Controller.text.trim(),
        openingBalancePaise: (balance * 100).round(),
        openingDate: _openingDate,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account updated successfully')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No account was updated')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update account: $e')),
      );
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E9EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: detailsGreen, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: detailsBackground,
      appBar: AppBar(
        backgroundColor: detailsBackground,
        foregroundColor: detailsNavy,
        elevation: 0,
        title: const Text(
          'Edit Account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _banks.contains(_bankNameController.text)
                  ? _bankNameController.text
                  : 'Other',
              decoration: _decoration('Bank name'),
              items: _banks.map((bank) {
                return DropdownMenuItem(
                  value: bank,
                  child: Text(bank),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _bankNameController.text = value;
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankNameController,
              decoration: _decoration('Bank name (custom)'),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Please enter the bank name'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNameController,
              decoration: _decoration('Account name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Please enter the account name'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _last4Controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: _decoration(
                'Last four digits',
                hint: 'e.g. 4858',
              ),
              validator: (value) {
                final digits = value?.trim() ?? '';
                if (digits.isNotEmpty &&
                    !RegExp(r'^\d{4}$').hasMatch(digits)) {
                  return 'Enter exactly four digits or leave blank';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _balanceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration('Opening balance (₹)'),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount < 0) {
                  return 'Enter a valid opening balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: _decoration('Opening date'),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatDate(_openingDate))),
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: detailsGreen,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveAccount,
                style: FilledButton.styleFrom(
                  backgroundColor: detailsGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
