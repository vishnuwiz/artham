import 'package:flutter/material.dart';
import '../../theme/artham_theme.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

const Color transferGreen = ArthamColors.lavender;
const Color transferNavy = ArthamColors.text;
const Color transferBackground = Colors.transparent;

class TransferMoneyScreen extends StatefulWidget {
  final AppDatabase database;

  const TransferMoneyScreen({super.key, required this.database});

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(text: 'Own account transfer');
  late final TransactionRepository _repository;

  List<BankAccount> _accounts = [];
  AccountBalanceSummary? _balanceSummary;
  int? _fromAccountId;
  int? _toAccountId;
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await _repository.getActiveAccounts();
      final summary = await _repository.getBalanceSummary();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _balanceSummary = summary;
        if (accounts.isNotEmpty) _fromAccountId = accounts.first.id;
        if (accounts.length > 1) _toAccountId = accounts[1].id;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountId == null || _toAccountId == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      await _repository.addTransfer(
        fromAccountId: _fromAccountId!,
        toAccountId: _toAccountId!,
        amountPaise: (amount * 100).round(),
        transactionDate: _date,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        title: const Text('Transfer Money', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        foregroundColor: transferNavy,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: transferGreen))
          : _error != null
              ? Center(child: Text('Unable to load accounts: $_error'))
              : _accounts.length < 2
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'Add at least two active bank accounts to make a transfer.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: ArthamColors.heroGradient,
                              border: ArthamColors.glassBorder,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 30),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Move money between your own accounts. Transfers do not count as income or expenses.',
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _accountDropdown(
                            label: 'From account',
                            value: _fromAccountId,
                            onChanged: (v) => setState(() {
                              _fromAccountId = v;
                              if (_toAccountId == v) {
                                _toAccountId = _accounts.firstWhere((a) => a.id != v).id;
                              }
                            }),
                          ),
                          if (_fromAccountId != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Available: ${_money(_balanceSummary?.accountBalancesPaise[_fromAccountId!] ?? 0)}',
                                style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _accountDropdown(
                            label: 'To account',
                            value: _toAccountId,
                            onChanged: (v) => setState(() => _toAccountId = v),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Transfer amount',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: ArthamColors.glass,
                            ),
                            validator: (value) {
                              final amount = double.tryParse((value ?? '').trim());
                              if (amount == null || amount <= 0) return 'Enter a valid amount';
                              final available = _balanceSummary?.accountBalancesPaise[_fromAccountId] ?? 0;
                              if ((amount * 100).round() > available) return 'Amount exceeds available balance';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: ArthamColors.glass,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text('Transfer date: ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: transferGreen,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: transferGreen,
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            child: _saving
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ArthamColors.onAccent))
                                : const Text('Confirm Transfer'),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _accountDropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: ArthamColors.glass,
      ),
      items: _accounts.map((account) {
        final balance = _balanceSummary?.accountBalancesPaise[account.id] ?? 0;
        return DropdownMenuItem(
          value: account.id,
          child: Text(
            '${bankAccountDisplayLabel(account.bankName, account.accountNumberLast4)} (${_money(balance)})',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Select an account' : null,
    );
  }
}
