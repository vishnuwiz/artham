import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/repositories/sms_import_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/sms_transaction_parser.dart';

const Color smsGreen = Color(0xFF13866A);
const Color smsNavy = Color(0xFF142B35);
const Color smsBackground = Color(0xFFF5F7F8);

class ImportSmsScreen extends StatefulWidget {
  final AppDatabase database;

  const ImportSmsScreen({
    super.key,
    required this.database,
  });

  @override
  State<ImportSmsScreen> createState() => _ImportSmsScreenState();
}

class _ImportSmsScreenState extends State<ImportSmsScreen> {
  final _smsController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _parser = SmsTransactionParser();

  late final TransactionRepository _transactionRepository;
  late final SmsImportRepository _smsImportRepository;

  ParsedSmsTransaction? _parsed;
  List<BankAccount> _accounts = [];
  List<Category> _categories = [];
  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime? _selectedDate;
  String? _fingerprint;
  String? _error;
  bool _isParsing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _transactionRepository = TransactionRepository(widget.database);
    _smsImportRepository = SmsImportRepository(widget.database);
  }

  @override
  void dispose() {
    _smsController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _parseMessage() async {
    final message = _smsController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Paste a bank transaction SMS first.');
      return;
    }

    setState(() {
      _isParsing = true;
      _parsed = null;
      _error = null;
    });

    try {
      final parsed = _parser.parse(message);
      if (parsed == null) {
        setState(() {
          _error = 'This message does not look like a supported debit or '
              'credit alert. You can still add it manually.';
          _isParsing = false;
        });
        return;
      }

      final fingerprint = smsMessageFingerprint(message);
      if (await _smsImportRepository.isDuplicate(fingerprint)) {
        setState(() {
          _error = 'This SMS has already been imported.';
          _isParsing = false;
        });
        return;
      }

      await _transactionRepository.seedDefaultCategories();
      final accounts = await _transactionRepository.getActiveAccounts();
      final categories =
          await _transactionRepository.getCategories(parsed.transactionType);

      if (!mounted) return;

      if (accounts.isEmpty) {
        setState(() {
          _error = 'Add a bank account before importing transactions.';
          _isParsing = false;
        });
        return;
      }

      final suggestedCategory = categories.where(
        (category) =>
            category.name.toLowerCase() ==
            parsed.suggestedCategory.toLowerCase(),
      );

      setState(() {
        _parsed = parsed;
        _accounts = accounts;
        _categories = categories;
        _selectedAccountId = accounts.first.id;
        _selectedCategoryId = suggestedCategory.isNotEmpty
            ? suggestedCategory.first.id
            : (categories.isNotEmpty ? categories.first.id : null);
        _selectedDate = parsed.transactionDate ?? DateTime.now();
        _amountController.text =
            (parsed.amountPaise / 100).toStringAsFixed(2);
        _descriptionController.text = parsed.description;
        _fingerprint = fingerprint;
        _isParsing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to parse this message: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _chooseDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _importTransaction() async {
    final parsed = _parsed;
    final fingerprint = _fingerprint;
    if (parsed == null || fingerprint == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter a valid transaction amount.');
      return;
    }
    if (_selectedAccountId == null || _selectedCategoryId == null) {
      setState(() => _error = 'Select an account and category.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _smsImportRepository.importTransaction(
        fingerprint: fingerprint,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        amountPaise: (amount * 100).round(),
        transactionType: parsed.transactionType,
        transactionDate: _selectedDate ?? DateTime.now(),
        description: _descriptionController.text.trim(),
        referenceNumber: parsed.referenceNumber,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS transaction imported successfully.'),
        ),
      );
      Navigator.pop(context, true);
    } on DuplicateSmsImportException {
      if (!mounted) return;
      setState(() {
        _error = 'This SMS was imported already. No duplicate was created.';
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to import transaction: $e';
        _isSaving = false;
      });
    }
  }

  Widget _buildReview() {
    final parsed = _parsed!;
    final isIncome = parsed.transactionType == 'income';

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Review transaction',
                  style: TextStyle(
                    color: smsNavy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isIncome ? smsGreen : const Color(0xFFC45D58))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isIncome ? 'INCOME' : 'EXPENSE',
                  style: TextStyle(
                    color: isIncome ? smsGreen : const Color(0xFFC45D58),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\\d*\\.?\\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<int>(
            initialValue: _selectedAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bank account',
              border: OutlineInputBorder(),
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
            onChanged: (value) =>
                setState(() => _selectedAccountId = value),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Category (suggested)',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem<int>(
                value: category.id,
                child: Text(category.name),
              );
            }).toList(),
            onChanged: (value) =>
                setState(() => _selectedCategoryId = value),
          ),
          const SizedBox(height: 13),
          InkWell(
            onTap: _chooseDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: parsed.transactionDate == null
                    ? 'Date (not found in message — confirm)'
                    : 'Transaction date',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today_rounded),
              ),
              child: Text(
                _formatDate(_selectedDate ?? DateTime.now()),
                style: const TextStyle(
                  color: smsNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (parsed.referenceNumber != null) ...[
            const SizedBox(height: 12),
            Text(
              'Reference: ${parsed.referenceNumber}',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _importTransaction,
              style: FilledButton.styleFrom(
                backgroundColor: smsGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_done_rounded),
              label: Text(_isSaving ? 'Importing...' : 'Confirm and import'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: smsBackground,
      appBar: AppBar(
        backgroundColor: smsBackground,
        foregroundColor: smsNavy,
        elevation: 0,
        title: const Text(
          'Import bank SMS',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: smsGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Paste one bank or UPI transaction alert. Artham parses it '
                    'on this device. The original message is not saved; only '
                    'the reviewed transaction and a duplicate-check fingerprint '
                    'are stored locally.',
                    style: TextStyle(
                      color: smsNavy,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _smsController,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) {
              if (_parsed != null || _error != null) {
                setState(() {
                  _parsed = null;
                  _fingerprint = null;
                  _error = null;
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Paste the bank SMS here...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8E8)),
              ),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isParsing ? null : _parseMessage,
              style: FilledButton.styleFrom(
                backgroundColor: smsNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(_isParsing ? 'Parsing...' : 'Parse message'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF9D3333),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          if (_parsed != null) _buildReview(),
        ],
      ),
    );
  }
}
