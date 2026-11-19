import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import '../../theme/category_icons.dart';

import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/merchant_intelligence.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';

Color get transactionGreen => ArthamColors.lavender;
Color get transactionNavy => ArthamColors.text;
const Color transactionBackground = Colors.transparent;

class AddTransactionScreen extends StatefulWidget {
  final AppDatabase database;

  const AddTransactionScreen({super.key, required this.database});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TransactionRepository _repository;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];

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
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      await _repository.seedDefaultCategories();

      final accounts = await _repository.getActiveAccounts();
      final balanceSummary = await _repository.getBalanceSummary();
      final categories = await _repository.getCategories(_transactionType);

      if (!mounted) return;

      setState(() {
        _accounts = accounts;
        _categories = categories;
        _balanceSummary = balanceSummary;
        _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
        _toAccountId = accounts.length > 1 ? accounts[1].id : null;
        _defaultCategoryId = categories.isNotEmpty ? categories.first.id : null;
        _selectedCategoryId = _defaultCategoryId;
        _categoryWasManuallySelected = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load form: $e')));
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
        _defaultCategoryId = categories.isNotEmpty ? categories.first.id : null;
        _selectedCategoryId = _defaultCategoryId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load categories: $e')));
    }
  }

  /// Keeps the destination account different from the source account.
  void _ensureDifferentDestination() {
    if (_accounts.length < 2) {
      _toAccountId = null;
      return;
    }
    if (_toAccountId == null || _toAccountId == _selectedAccountId) {
      _toAccountId = _accounts.firstWhere((a) => a.id != _selectedAccountId).id;
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
        _selectedCategoryId =
            suggestedCategory != null && suggestedCategory.isNotEmpty
            ? suggestedCategory.first.id
            : _defaultCategoryId;
      }
    });
  }

  void _addTag([String? rawValue]) {
    final value = (rawValue ?? _tagController.text)
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return;

    if (_tags.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 8 tags.')),
      );
      return;
    }
    if (_tags.any((tag) => tag.toLowerCase() == value.toLowerCase())) {
      _tagController.clear();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _tags.add(value);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() => _tags.remove(tag));
  }

  String? get _tagNotes =>
      _tags.isEmpty ? null : _tags.map((tag) => '#$tag').join(', ');

  Widget _buildTagsField() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tagController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTag(),
            decoration:
                _decoration(
                  'Tags (optional)',
                  hint: 'Add a tag and press enter',
                  prefix: Icon(
                    Icons.sell_outlined,
                    color: transactionGreen,
                  ),
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: 'Add tag',
                    onPressed: () => _addTag(),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  child: InputChip(
                    key: ValueKey(tag),
                    label: Text('#$tag'),
                    onDeleted: () => _removeTag(tag),
                    deleteIcon: const Icon(Icons.close_rounded, size: 15),
                    backgroundColor: transactionGreen.withValues(alpha: 0.12),
                    side: BorderSide(
                      color: transactionGreen.withValues(alpha: 0.35),
                    ),
                    labelStyle: TextStyle(
                      color: transactionNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        _transactionDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _transactionDate.hour,
          _transactionDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionDate),
    );

    if (selected != null) {
      setState(() {
        _transactionDate = DateTime(
          _transactionDate.year,
          _transactionDate.month,
          _transactionDate.day,
          selected.hour,
          selected.minute,
        );
      });
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
        notes: _tagNotes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer saved successfully!')),
      );
      await showSavedCheck(context);
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _saveTransaction() async {
    if (_isTransfer) return _saveTransfer();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccountId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bank account and category.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

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
        notes: _tagNotes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved successfully!')),
      );

      await showSavedCheck(context);
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save transaction: $e')));
    }
  }

  Future<int?> _createCategoryFromPicker() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('New category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: CategoryRepository.maxNameLength,
            decoration: const InputDecoration(
              labelText: 'Category name',
              hintText: 'e.g. Coffee',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (name == null || name.trim().isEmpty) return null;

      final id = await CategoryRepository(widget.database).createCategory(
        name: name,
        type: _transactionType,
        iconKey: fallbackCategoryIconKey,
        colorHex: '#B99AFF',
      );
      final categories = await _repository.getCategories(_transactionType);

      if (!mounted) return null;
      setState(() {
        _categories = categories;
        _selectedCategoryId = id;
        _categoryWasManuallySelected = true;
      });
      return id;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _selectCategory() async {
    if (_categories.isEmpty) return;

    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (sheetContext) {
        var query = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCategories = _categories.where((category) {
              return category.name.toLowerCase().contains(
                query.trim().toLowerCase(),
              );
            }).toList();

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.76,
                      decoration: BoxDecoration(
                        // A darker, more opaque tint keeps the form behind the
                        // sheet from competing with the category picker.
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xE91D1B30),
                            Color(0xED292738),
                            Color(0xEF20202B),
                          ],
                        ),
                        border: Border.all(
                          color: ArthamColors.text.withValues(alpha: 0.20),
                          width: 1,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: ArthamColors.onHeroFaint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: ArthamColors.debit),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Select Category',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: transactionNavy,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final id =
                                        await _createCategoryFromPicker();
                                    if (id != null && sheetContext.mounted) {
                                      Navigator.pop(sheetContext, id);
                                    }
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 19),
                                  label: const Text('New'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: ArthamColors.lavender,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: TextField(
                              onChanged: (value) =>
                                  setSheetState(() => query = value),
                              decoration: InputDecoration(
                                hintText: 'Search category...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: ArthamColors.text.withValues(
                                  alpha: 0.055,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: ArthamColors.line,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: ArthamColors.line,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: filteredCategories.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching categories',
                                      style: TextStyle(
                                        color: ArthamColors.muted,
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      4,
                                      18,
                                      24,
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 10,
                                      children: filteredCategories.map((
                                        category,
                                      ) {
                                        final selected =
                                            category.id == _selectedCategoryId;
                                        final color = categoryColorFor(
                                          category.colorHex,
                                        );

                                        return ChoiceChip(
                                          showCheckmark: false,
                                          selected: selected,
                                          onSelected: (_) {
                                            HapticFeedback.selectionClick();
                                            Navigator.pop(
                                              sheetContext,
                                              category.id,
                                            );
                                          },
                                          avatar: Icon(
                                            categoryIconFor(category.iconKey),
                                            size: 17,
                                            color: color,
                                          ),
                                          label: Text(category.name),
                                          labelStyle: TextStyle(
                                            color: selected
                                                ? color
                                                : transactionNavy,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          backgroundColor: ArthamColors.onHero
                                              .withValues(alpha: 0.035),
                                          selectedColor: color.withValues(
                                            alpha: 0.19,
                                          ),
                                          side: BorderSide(
                                            color: color.withValues(
                                              alpha: selected ? 1 : 0.65,
                                            ),
                                            width: selected ? 1.8 : 1,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 8,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedId != null && mounted) {
      setState(() {
        _selectedCategoryId = selectedId;
        _categoryWasManuallySelected = true;
      });
    }
  }

  InputDecoration _decoration(String label, {String? hint, Widget? prefix}) {
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
        borderSide: BorderSide(color: ArthamColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: transactionGreen, width: 1.5),
      ),
    );
  }

  Color get _accentColor {
    switch (_transactionType) {
      case 'income':
        return ArthamColors.mint;
      case 'transfer':
        return ArthamColors.lavender;
      default:
        return ArthamColors.debit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: transactionNavy,
        elevation: 0,
        title: const Text(
          'New Transaction',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: transactionGreen))
          : _accounts.isEmpty
          ? _buildNoAccounts()
          : _buildForm(_accentColor),
    );
  }

  Widget _caption(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          color: ArthamColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// A rounded, tappable choice used for categories and accounts. The fill and
  /// border animate when it becomes selected.
  Widget _choice({
    required Key key,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return PressableScale(
      key: key,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : ArthamColors.glassSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : ArthamColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _categoryRow(Color accent) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final category in _categories) ...[
            Builder(
              builder: (context) {
                final color = categoryColorFor(category.colorHex);
                final selected = category.id == _selectedCategoryId;
                return _choice(
                  key: ValueKey('category-chip-${category.id}'),
                  selected: selected,
                  color: color,
                  onTap: () => setState(() {
                    _selectedCategoryId = category.id;
                    _categoryWasManuallySelected = true;
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIconFor(category.iconKey),
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.name,
                        style: TextStyle(
                          color: transactionNavy,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          _choice(
            key: const ValueKey('category-more-chip'),
            selected: false,
            color: accent,
            onTap: _selectCategory,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 18, color: ArthamColors.muted),
                const SizedBox(width: 8),
                Text(
                  'More',
                  style: TextStyle(color: ArthamColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow({
    required List<BankAccount> accounts,
    required int? selectedId,
    required ValueChanged<int> onSelected,
    required Color accent,
    required String keyPrefix,
  }) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final account in accounts) ...[
            _choice(
              key: ValueKey('$keyPrefix-${account.id}'),
              selected: account.id == selectedId,
              color: accent,
              onTap: () => onSelected(account.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.bankName,
                    style: TextStyle(
                      color: transactionNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    accountNumberLastFourLabel(account.accountNumberLast4),
                    style: TextStyle(color: ArthamColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _pickerButton({
    required String caption,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ArthamColors.glass,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ArthamColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: transactionGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: TextStyle(color: ArthamColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: transactionNavy,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildForm(Color accent) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final label = _isTransfer
        ? 'TRANSFER AMOUNT'
        : (_transactionType == 'income' ? 'INCOME AMOUNT' : 'EXPENSE AMOUNT');
    final fromAccounts = _accounts;
    final toAccounts = _accounts
        .where((account) => account.id != _selectedAccountId)
        .toList();

    return Form(
      key: _formKey,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 130),
            children: [
              _Rise(
                index: 0,
                child: _TypeSwitch(
                  value: _transactionType,
                  onChanged: _changeTransactionType,
                ),
              ),
              const SizedBox(height: 20),
              _Rise(
                index: 1,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  decoration: BoxDecoration(
                    gradient: ArthamColors.glassGradient,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: ArthamColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        autofocus: false,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        style: TextStyle(
                          color: transactionNavy,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          prefixStyle: TextStyle(
                            color: accent,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: ArthamColors.faint,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        validator: (value) {
                          final amount = double.tryParse(value?.trim() ?? '');

                          if (amount == null ||
                              !amount.isFinite ||
                              amount <= 0) {
                            return 'Enter a valid amount';
                          }

                          if ((amount * 100).round() <= 0) {
                            return 'Amount must be at least ₹0.01';
                          }

                          if (_isTransfer) {
                            final available =
                                _balanceSummary
                                    ?.accountBalancesPaise[_selectedAccountId] ??
                                0;
                            if ((amount * 100).round() > available) {
                              return 'Amount exceeds available balance';
                            }
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _amountController,
                        builder: (context, value, _) {
                          return Container(
                            height: 3,
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: ArthamColors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: AnimatedFractionallySizedBox(
                              duration: reduce
                                  ? Duration.zero
                                  : const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.centerLeft,
                              widthFactor: value.text.isEmpty ? 0.3 : 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const SizedBox(height: 3),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _Rise(
                index: 2,
                child: AnimatedSize(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    child: KeyedSubtree(
                      key: ValueKey<bool>(_isTransfer),
                      child: _isTransfer
                          ? _transferSection(
                              accent,
                              fromAccounts,
                              toAccounts,
                            )
                          : _expenseIncomeSection(accent, fromAccounts),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _Rise(
                index: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _pickerButton(
                        caption: 'Transaction Date',
                        value: _formatDate(_transactionDate),
                        icon: Icons.calendar_month_outlined,
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pickerButton(
                        caption: 'Transaction Time',
                        value: _formatTime(_transactionDate),
                        icon: Icons.access_time_rounded,
                        onTap: _selectTime,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Rise(
                index: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 150,
                      onChanged: _handleDescriptionChanged,
                      decoration: _decoration(
                        'Description (optional)',
                        hint: 'e.g. Lunch with friends',
                        prefix: Icon(
                          Icons.notes_rounded,
                          color: transactionGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTagsField(),
                    if (_merchantSuggestion != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: transactionGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Recognised ${_merchantSuggestion!.name} · '
                              'suggested ${_merchantSuggestion!.categoryName}',
                              style: TextStyle(
                                color: transactionGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildSaveBar(accent),
          ),
        ],
      ),
    );
  }

  Widget _expenseIncomeSection(Color accent, List<BankAccount> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _caption('Category'),
        _categoryRow(accent),
        const SizedBox(height: 20),
        _caption('Account'),
        _accountRow(
          accounts: accounts,
          selectedId: _selectedAccountId,
          onSelected: (id) => setState(() => _selectedAccountId = id),
          accent: accent,
          keyPrefix: 'account-chip',
        ),
      ],
    );
  }

  Widget _transferSection(
    Color accent,
    List<BankAccount> fromAccounts,
    List<BankAccount> toAccounts,
  ) {
    final available =
        _balanceSummary?.accountBalancesPaise[_selectedAccountId] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(
            'Move money between your own accounts. Transfers do not count '
            'as income or expenses.',
            style: TextStyle(color: ArthamColors.muted, fontSize: 12.5),
          ),
        ),
        _caption('From account'),
        _accountRow(
          accounts: fromAccounts,
          selectedId: _selectedAccountId,
          onSelected: (id) => setState(() {
            _selectedAccountId = id;
            _ensureDifferentDestination();
          }),
          accent: accent,
          keyPrefix: 'from-chip',
        ),
        if (_selectedAccountId != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Available: ${_money(available)}',
              style: TextStyle(color: ArthamColors.muted, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _caption('To account')),
            if (_accounts.length >= 2 && _toAccountId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IconButton.filledTonal(
                  key: const Key('swap-accounts-button'),
                  tooltip: 'Swap accounts',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      final from = _selectedAccountId;
                      _selectedAccountId = _toAccountId;
                      _toAccountId = from;
                    });
                  },
                  icon: const Icon(Icons.swap_vert_rounded, size: 20),
                ),
              ),
          ],
        ),
        if (_accounts.length < 2)
          Text(
            'Add at least two active bank accounts to make a transfer.',
            style: TextStyle(color: ArthamColors.debit, fontSize: 13),
          )
        else
          _accountRow(
            accounts: toAccounts,
            selectedId: _toAccountId,
            onSelected: (id) => setState(() => _toAccountId = id),
            accent: accent,
            keyPrefix: 'to-chip',
          ),
      ],
    );
  }

  Widget _buildSaveBar(Color accent) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final enabled = !_isSaving && !(_isTransfer && _accounts.length < 2);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ArthamColors.ink.withValues(alpha: 0),
            ArthamColors.ink.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: PressableScale(
          onTap: enabled ? _saveTransaction : null,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? accent : accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(29),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.32),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: ArthamColors.onAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.check_circle_outline_rounded,
                        color: ArthamColors.onAccent,
                      ),
                const SizedBox(width: 10),
                Text(
                  _isSaving
                      ? 'Saving...'
                      : (_isTransfer ? 'Confirm Transfer' : 'Save Transaction'),
                  style: TextStyle(
                    color: ArthamColors.onAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            Icon(
              Icons.account_balance_outlined,
              size: 60,
              color: transactionGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'No bank accounts available',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: transactionNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
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


/// Fades and lifts a child in, one after another by [index]. Skipped when the
/// system "reduce motion" setting is on.
class _Rise extends StatelessWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = index * 70;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Expense / Income / Transfer switch. A capsule slides under the selected
/// label, like the bottom tab bar.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = [
    ('expense', 'Expense', Icons.arrow_upward_rounded),
    ('income', 'Income', Icons.arrow_downward_rounded),
    ('transfer', 'Transfer', Icons.swap_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 340);
    final index = _items.indexWhere((item) => item.$1 == value);
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: ArthamColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segment = constraints.maxWidth / _items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: index * segment,
                width: segment,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  key: const ValueKey('type-switch-capsule'),
                  decoration: BoxDecoration(
                    color: ArthamColors.tabCapsule,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final item in _items)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: item.$1 == value,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            if (item.$1 != value) {
                              HapticFeedback.selectionClick();
                            }
                            onChanged(item.$1);
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.$3,
                                  size: 16,
                                  color: item.$1 == value
                                      ? ArthamColors.onAccent
                                      : ArthamColors.tabIdle,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  item.$2,
                                  style: TextStyle(
                                    color: item.$1 == value
                                        ? ArthamColors.onAccent
                                        : ArthamColors.tabIdle,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
