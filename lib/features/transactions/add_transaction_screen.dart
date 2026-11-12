
import 'package:flutter/material.dart';
import '../../theme/artham_theme.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/merchant_intelligence.dart';
import '../../data/repositories/transaction_repository.dart';

const Color transactionGreen = ArthamColors.lavender;
const Color transactionNavy = ArthamColors.text;
const Color transactionBackground = Colors.transparent;

class AddTransactionScreen extends StatefulWidget {
  final AppDatabase database;

  const AddTransactionScreen({
    super.key,
    required this.database,
  });

  @override
  State<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TransactionRepository _repository;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<BankAccount> _accounts = [];
  List<Category> _categories = [];

  int? _selectedAccountId;
  int? _toAccountId;
  AccountBalanceSummary? _balanceSummary;
  int? _selectedCategoryId;
  int? _defaultCategoryId;
  bool _categoryWasManuallySelected = false;
  MerchantRecognition? _merchantSuggestion;

  String _transactionType = 'expense';
  DateTime _transactionDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isTransfer => _transactionType == 'transfer';

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _loadFormData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      await _repository.seedDefaultCategories();

      final accounts = await _repository.getActiveAccounts();
      final balanceSummary = await _repository.getBalanceSummary();
      final categories =
          await _repository.getCategories(_transactionType);

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _balanceSummary = balanceSummary;
        _selectedAccountId =
            accounts.isNotEmpty ? accounts.first.id : null;
        _toAccountId = accounts.length > 1 ? accounts[1].id : null;
        _defaultCategoryId =
            categories.isNotEmpty ? categories.first.id : null;
        _selectedCategoryId = _defaultCategoryId;
        _categoryWasManuallySelected = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load form: $e')),
      );
    }
  }

  Future<void> _changeTransactionType(String type) async {
    if (_transactionType == type) return;

    if (type == 'transfer') {
      // Transfers have no category, so there is nothing to load.
      setState(() {
        _transactionType = type;
        _merchantSuggestion = null;
        _ensureDifferentDestination();
      });
      return;
    }

    setState(() {
      _transactionType = type;
      _selectedCategoryId = null;
      _defaultCategoryId = null;
      _categoryWasManuallySelected = false;
      _merchantSuggestion = null;
      _categories = [];
      _isLoading = true;
    });

    try {
      final categories = await _repository.getCategories(type);

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _defaultCategoryId =
            categories.isNotEmpty ? categories.first.id : null;
        _selectedCategoryId = _defaultCategoryId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load categories: $e')),
      );
    }
  }

  /// Keeps the destination account different from the source account.
  void _ensureDifferentDestination() {
    if (_accounts.length < 2) {
      _toAccountId = null;
      return;
    }
    if (_toAccountId == null || _toAccountId == _selectedAccountId) {
      _toAccountId =
          _accounts.firstWhere((a) => a.id != _selectedAccountId).id;
    }
  }

  void _handleDescriptionChanged(String value) {
    final match = _transactionType == 'expense'
        ? MerchantIntelligence.recognize(value)
        : null;
    final suggestedCategory = match == null
        ? null
        : _categories.where((item) => item.name == match.categoryName);

    setState(() {
      _merchantSuggestion = match;
      if (!_categoryWasManuallySelected) {
        _selectedCategoryId = suggestedCategory != null &&
                suggestedCategory.isNotEmpty
            ? suggestedCategory.first.id
            : _defaultCategoryId;
      }
    });
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() => _transactionDate = selected);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _saveTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    final fromId = _selectedAccountId;
    final toId = _toAccountId;
    if (fromId == null || toId == null || fromId == toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose two different accounts for the transfer.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      final description = _descriptionController.text.trim();
      await _repository.addTransfer(
        fromAccountId: fromId,
        toAccountId: toId,
        amountPaise: (amount * 100).round(),
        transactionDate: _transactionDate,
        description: description.isEmpty ? 'Own account transfer' : description,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer saved successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _saveTransaction() async {
    if (_isTransfer) return _saveTransfer();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bank account and category.'),
        ),
      );
      return;
    }

    final amount =
        double.tryParse(_amountController.text.trim());

    if (amount == null || !amount.isFinite || amount <= 0) {
      return;
    }

    final amountPaise = (amount * 100).round();

    setState(() => _isSaving = true);

    try {
      await _repository.addTransaction(
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        amountPaise: amountPaise,
        transactionType: _transactionType,
        transactionDate: _transactionDate,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction saved successfully!'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save transaction: $e')),
      );
    }
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: ArthamColors.glass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: ArthamColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: transactionGreen,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _transactionType == 'income';
    final accent =
        _transactionType == 'expense' ? ArthamColors.debit : transactionGreen;

    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: transactionNavy,
        elevation: 0,
        title: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: transactionGreen,
              ),
            )
          : _accounts.isEmpty
              ? _buildNoAccounts()
              : _buildForm(isIncome, accent),
    );
  }

  Widget _buildForm(bool isIncome, Color accent) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
              ButtonSegment(
                value: 'transfer',
                label: Text('Transfer'),
                icon: Icon(Icons.swap_horiz_rounded),
              ),
            ],
            showSelectedIcon: false,
            selected: {_transactionType},
            onSelectionChanged: (selection) {
              _changeTransactionType(selection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: accent.withValues(alpha: 0.13),
              selectedForegroundColor: accent,
            ),
          ),

          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: ArthamColors.glass,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ArthamColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTransfer
                      ? 'TRANSFER AMOUNT'
                      : (isIncome ? 'INCOME AMOUNT' : 'EXPENSE AMOUNT'),
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  autofocus: false,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: TextStyle(
                    color: accent,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: accent,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    final amount =
                        double.tryParse(value?.trim() ?? '');

                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0) {
                      return 'Enter a valid amount';
                    }

                    if ((amount * 100).round() <= 0) {
                      return 'Amount must be at least ₹0.01';
                    }

                    if (_isTransfer) {
                      final available = _balanceSummary
                              ?.accountBalancesPaise[_selectedAccountId] ??
                          0;
                      if ((amount * 100).round() > available) {
                        return 'Amount exceeds available balance';
                      }
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_isTransfer) ...[
            const Text(
              'Move money between your own accounts. Transfers do not count '
              'as income or expenses.',
              style: TextStyle(color: ArthamColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            _isTransfer ? 'TRANSFER DETAILS' : 'TRANSACTION DETAILS',
            style: TextStyle(
              color: ArthamColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 13),

          DropdownButtonFormField<int>(
            initialValue: _selectedAccountId,
            isExpanded: true,
            decoration: _decoration(
              _isTransfer ? 'From account' : 'Bank Account',
              prefix: const Icon(
                Icons.account_balance_outlined,
                color: transactionGreen,
              ),
            ),
            items: _accounts.map((account) {
              return DropdownMenuItem<int>(
                value: account.id,
                child: Text(
                  bankAccountDisplayLabel(account.bankName, account.accountNumberLast4),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAccountId = value;
                if (_isTransfer) _ensureDifferentDestination();
              });
            },
            validator: (value) =>
                value == null ? 'Select a bank account' : null,
          ),

          if (_isTransfer) ...[
            if (_selectedAccountId != null) ...[
              const SizedBox(height: 6),
              Text(
                'Available: ${_money(_balanceSummary?.accountBalancesPaise[_selectedAccountId] ?? 0)}',
                style: const TextStyle(
                  color: ArthamColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_accounts.length < 2)
              const Text(
                'Add at least two active bank accounts to make a transfer.',
                style: TextStyle(color: ArthamColors.debit, fontSize: 13),
              )
            else
              DropdownButtonFormField<int>(
                key: ValueKey<int?>(_toAccountId),
                initialValue: _toAccountId,
                isExpanded: true,
                decoration: _decoration(
                  'To account',
                  prefix: const Icon(
                    Icons.account_balance_outlined,
                    color: transactionGreen,
                  ),
                ),
                items: _accounts
                    .where((account) => account.id != _selectedAccountId)
                    .map((account) {
                  return DropdownMenuItem<int>(
                    value: account.id,
                    child: Text(
                      bankAccountDisplayLabel(
                        account.bankName,
                        account.accountNumberLast4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _toAccountId = value);
                },
                validator: (value) =>
                    value == null ? 'Select a destination account' : null,
              ),
          ] else ...[
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                key: ValueKey<int?>(_selectedCategoryId),
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: _decoration(
                  'Category',
                  prefix: const Icon(
                    Icons.category_outlined,
                    color: transactionGreen,
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                    _categoryWasManuallySelected = true;
                  });
                },
                validator: (value) =>
                    value == null ? 'Select a category' : null,
              ),
          ],

          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            maxLength: 150,
            onChanged: _handleDescriptionChanged,
            decoration: _decoration(
              'Description (optional)',
              hint: 'e.g. Lunch with friends',
              prefix: const Icon(
                Icons.notes_rounded,
                color: transactionGreen,
              ),
            ),
          ),
          if (_merchantSuggestion != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 15,
                  color: transactionGreen,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Recognised ${_merchantSuggestion!.name} · '
                    'suggested ${_merchantSuggestion!.categoryName}',
                    style: const TextStyle(
                      color: transactionGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(15),
            child: InputDecorator(
              decoration: _decoration(
                'Transaction Date',
                prefix: const Icon(
                  Icons.calendar_month_outlined,
                  color: transactionGreen,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_formatDate(_transactionDate)),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: transactionGreen,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 55,
            child: FilledButton.icon(
              onPressed: _isSaving || (_isTransfer && _accounts.length < 2)
                  ? null
                  : _saveTransaction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: ArthamColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: ArthamColors.onAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isSaving
                    ? 'Saving...'
                    : (_isTransfer ? 'Confirm Transfer' : 'Save Transaction'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccounts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 60,
              color: transactionGreen,
            ),
            const SizedBox(height: 16),
            const Text(
              'No bank accounts available',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: transactionNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please add an active bank account before recording a transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ArthamColors.muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
