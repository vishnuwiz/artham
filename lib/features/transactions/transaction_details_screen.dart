import 'package:flutter/material.dart';
import '../../theme/artham_theme.dart';
import '../../theme/category_icons.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

const Color transactionGreen = ArthamColors.lavender;
const Color transactionNavy = ArthamColors.text;
const Color transactionBackground = Colors.transparent;

class TransactionDetailsScreen extends StatefulWidget {
  final AppDatabase database;
  final MoneyTransaction transaction;

  const TransactionDetailsScreen({
    super.key,
    required this.database,
    required this.transaction,
  });

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  late final TransactionRepository _repository;
  late Future<_TransactionDetailsData> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _detailsFuture = _loadDetails();
  }

  Future<_TransactionDetailsData> _loadDetails() async {
    final account = await (widget.database.select(widget.database.bankAccounts)
          ..where((item) => item.id.equals(widget.transaction.accountId)))
        .getSingleOrNull();

    Category? category;
    final categoryId = widget.transaction.categoryId;
    if (categoryId != null) {
      category = await (widget.database.select(widget.database.categories)
            ..where((item) => item.id.equals(categoryId)))
          .getSingleOrNull();
    }

    Merchant? merchant;
    final merchantId = widget.transaction.merchantId;
    if (merchantId != null) {
      merchant = await (widget.database.select(widget.database.merchants)
            ..where((item) => item.id.equals(merchantId)))
          .getSingleOrNull();
    }

    return _TransactionDetailsData(
      account: account,
      category: category,
      merchant: merchant,
    );
  }

  String _formatAmount(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _editTransaction() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _EditTransactionScreen(
          database: widget.database,
          transaction: widget.transaction,
        ),
      ),
    );

    if (updated == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ArthamColors.debit,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted =
          await _repository.deleteTransaction(widget.transaction.id);
      if (!mounted) return;

      if (deleted) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction could not be deleted.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete transaction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final isIncome = transaction.transactionType == 'income';
    final amountColor =
        isIncome ? transactionGreen : ArthamColors.debit;

    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: transactionNavy,
        elevation: 0,
        title: const Text(
          'Transaction Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit transaction',
            onPressed: _editTransaction,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete transaction',
            onPressed: _deleteTransaction,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_TransactionDetailsData>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load details: ${snapshot.error}'));
          }

          final details = snapshot.data!;
          final categoryName = details.category?.name ?? 'Uncategorised';
          final accountName = details.account == null
              ? 'Inactive account'
              : bankAccountDisplayLabel(
                  details.account!.bankName,
                  details.account!.accountNumberLast4,
                );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ArthamColors.glassGradient,
                  border: ArthamColors.glassBorder,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: amountColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        isIncome
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: amountColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: const TextStyle(color: ArthamColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isIncome ? '+' : '−'}${_formatAmount(transaction.amountPaise)}',
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transaction.description?.isNotEmpty == true
                          ? transaction.description!
                          : categoryName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: transactionNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: ArthamColors.glassGradient,
                  border: ArthamColors.glassBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _detailRow('Category', categoryName),
                    if (details.merchant != null)
                      _detailRow('Merchant', details.merchant!.name),
                    _detailRow('Account', accountName),
                    _detailRow('Date', _formatDate(transaction.transactionDate)),
                    _detailRow('Type', isIncome ? 'Income' : 'Expense'),
                    _detailRow('Source', transaction.source),
                    if (transaction.referenceNumber?.isNotEmpty == true)
                      _detailRow('Reference', transaction.referenceNumber!),
                    if (transaction.notes?.isNotEmpty == true)
                      _detailRow('Notes', transaction.notes!),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: _editTransaction,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit transaction'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: transactionGreen,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: transactionGreen),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _deleteTransaction,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete transaction'),
                style: TextButton.styleFrom(
                  foregroundColor: ArthamColors.debit,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: ArthamColors.muted)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: transactionNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailsData {
  final BankAccount? account;
  final Category? category;
  final Merchant? merchant;

  const _TransactionDetailsData({
    required this.account,
    required this.category,
    required this.merchant,
  });
}

class _EditTransactionScreen extends StatefulWidget {
  final AppDatabase database;
  final MoneyTransaction transaction;

  const _EditTransactionScreen({
    required this.database,
    required this.transaction,
  });

  @override
  State<_EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<_EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TransactionRepository _repository;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  List<BankAccount> _accounts = [];
  List<Category> _categories = [];
  int? _selectedAccountId;
  int? _selectedCategoryId;
  late DateTime _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  String get _type => widget.transaction.transactionType;

  @override
  void initState() {
    super.initState();
    _repository = TransactionRepository(widget.database);
    _amountController = TextEditingController(
      text: (widget.transaction.amountPaise / 100).toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description ?? '',
    );
    _selectedDate = widget.transaction.transactionDate;
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final accounts = await _repository.getActiveAccounts();
      final currentAccount =
          await (widget.database.select(widget.database.bankAccounts)
                ..where((item) => item.id.equals(widget.transaction.accountId)))
              .getSingleOrNull();

      if (currentAccount != null &&
          !accounts.any((item) => item.id == currentAccount.id)) {
        accounts.add(currentAccount);
      }

      final categories = await _repository.getCategories(_type);
      // Keep a hidden category selectable for the transaction that uses it,
      // so editing the amount doesn't silently change its category.
      final currentCategoryId = widget.transaction.categoryId;
      if (currentCategoryId != null &&
          !categories.any((item) => item.id == currentCategoryId)) {
        final currentCategory =
            await (widget.database.select(widget.database.categories)
                  ..where((item) => item.id.equals(currentCategoryId)))
                .getSingleOrNull();
        if (currentCategory != null && currentCategory.type == _type) {
          categories.add(currentCategory);
        }
      }
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _categories = categories;
          _selectedAccountId = widget.transaction.accountId;
          _selectedCategoryId = _categories.any(
            (item) => item.id == widget.transaction.categoryId,
          )
              ? widget.transaction.categoryId
              : (_categories.isNotEmpty ? _categories.first.id : null);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account and category.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await _repository.updateTransaction(
        transactionId: widget.transaction.id,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        amountPaise: (amount * 100).round(),
        transactionType: _type,
        transactionDate: _selectedDate,
        description: _descriptionController.text,
        notes: widget.transaction.notes,
      );

      if (!mounted) return;
      if (updated) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transaction was updated.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update transaction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _type == 'income' ? 'Income' : 'Expense';

    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: transactionNavy,
        elevation: 0,
        title: const Text(
          'Edit Transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text('Unable to load form: $_loadError'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: ArthamColors.glassGradient,
                          border: ArthamColors.glassBorder,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: const TextStyle(
                                color: transactionGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final amount =
                                    double.tryParse((value ?? '').trim());
                                if (amount == null || amount <= 0) {
                                  return 'Enter a valid amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedAccountId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Account',
                                border: OutlineInputBorder(),
                              ),
                              items: _accounts
                                  .map(
                                    (account) => DropdownMenuItem<int>(
                                      value: account.id,
                                      child: Text(
                                        bankAccountDisplayLabel(account.bankName, account.accountNumberLast4),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedAccountId = value),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedCategoryId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem<int>(
                                      value: category.id,
                                      child: CategoryLabel(category: category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedCategoryId = value),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(10),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Transaction date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_month_outlined),
                                ),
                                child: Text(_formatDate(_selectedDate)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: transactionGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ArthamColors.onAccent,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
