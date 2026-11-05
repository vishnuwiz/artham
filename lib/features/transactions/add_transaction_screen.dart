
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

const Color transactionGreen = Color(0xFF13866A);
const Color transactionNavy = Color(0xFF142B35);
const Color transactionBackground = Color(0xFFF5F7F8);

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
  int? _selectedCategoryId;

  String _transactionType = 'expense';
  DateTime _transactionDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

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
      final categories =
          await _repository.getCategories(_transactionType);

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _selectedAccountId =
            accounts.isNotEmpty ? accounts.first.id : null;
        _selectedCategoryId =
            categories.isNotEmpty ? categories.first.id : null;
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

    setState(() {
      _transactionType = type;
      _selectedCategoryId = null;
      _categories = [];
      _isLoading = true;
    });

    try {
      final categories = await _repository.getCategories(type);

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _selectedCategoryId =
            categories.isNotEmpty ? categories.first.id : null;
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

  Future<void> _saveTransaction() async {
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE5E9EB)),
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
    final accent = isIncome ? transactionGreen : const Color(0xFFC45D58);

    return Scaffold(
      backgroundColor: transactionBackground,
      appBar: AppBar(
        backgroundColor: transactionBackground,
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
            ],
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E9EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncome ? 'INCOME AMOUNT' : 'EXPENSE AMOUNT',
                  style: const TextStyle(
                    color: Colors.black45,
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

                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'TRANSACTION DETAILS',
            style: TextStyle(
              color: Colors.black54,
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
              'Bank Account',
              prefix: const Icon(
                Icons.account_balance_outlined,
                color: transactionGreen,
              ),
            ),
            items: _accounts.map((account) {
              return DropdownMenuItem<int>(
                value: account.id,
                child: Text(
                  '${account.bankName} · ${account.accountName}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedAccountId = value);
            },
            validator: (value) =>
                value == null ? 'Select a bank account' : null,
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
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
              setState(() => _selectedCategoryId = value);
            },
            validator: (value) =>
                value == null ? 'Select a category' : null,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            maxLength: 150,
            decoration: _decoration(
              'Description (optional)',
              hint: 'e.g. Lunch with friends',
              prefix: const Icon(
                Icons.notes_rounded,
                color: transactionGreen,
              ),
            ),
          ),

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
              onPressed: _isSaving ? null : _saveTransaction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Transaction',
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
              style: TextStyle(color: Colors.black54),
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
