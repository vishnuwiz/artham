import 'dart:convert';

import 'package:excel_plus/excel_plus.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/bank_statement_parser.dart';
import '../../data/repositories/bank_statement_import_repository.dart';
import '../../data/repositories/transaction_repository.dart';

const Color _statementGreen = Color(0xFF13866A);
const Color _statementNavy = Color(0xFF142B35);
const Color _statementBackground = Color(0xFFF5F7F8);

class BankStatementImportScreen extends StatefulWidget {
  final AppDatabase database;

  const BankStatementImportScreen({
    super.key,
    required this.database,
  });

  @override
  State<BankStatementImportScreen> createState() =>
      _BankStatementImportScreenState();
}

class _BankStatementImportScreenState extends State<BankStatementImportScreen> {
  static const int _maximumFileBytes = 15 * 1024 * 1024;

  List<BankAccount> _accounts = [];
  int? _selectedAccountId;
  String? _fileName;
  Map<String, List<List<String>>> _sheets = {};
  String? _selectedSheet;
  List<List<String>> _selectedRows = [];
  int _headerRowIndex = 0;
  StatementColumnMapping? _mapping;
  StatementParsingResult? _parseResult;
  bool _isLoadingAccounts = true;
  bool _isPickingFile = false;
  bool _isImporting = false;
  String? _error;
  StatementImportResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts =
          await TransactionRepository(widget.database).getActiveAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
        _isLoadingAccounts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load bank accounts: $error';
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _pickStatement() async {
    setState(() {
      _isPickingFile = true;
      _error = null;
      _lastResult = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );
      if (file == null) {
        if (mounted) setState(() => _isPickingFile = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maximumFileBytes) {
        throw const FormatException('Choose a statement smaller than 15 MB.');
      }

      final extension = (file.extension ?? '').toLowerCase();
      late final Map<String, List<List<String>>> sheets;
      if (extension == 'csv') {
        final csvText = utf8
            .decode(bytes, allowMalformed: true)
            .replaceFirst('\uFEFF', '');
        final workbook = Excel.fromCsv(csvText, sheetName: 'Statement');
        final sheet = workbook['Statement'];
        sheets = {
          'Statement': sheet.rows
              .map((row) => row.map((cell) => cell?.displayText ?? '').toList())
              .toList(),
        };
      } else {
        final workbook = await Excel.decodeBytesAsync(bytes);
        sheets = {
          for (final sheetName in workbook.tables.keys)
            sheetName: workbook[sheetName].rows
                .map((row) => row.map((cell) => cell?.displayText ?? '').toList())
                .toList(),
        };
      }

      if (sheets.isEmpty || sheets.values.every((rows) => rows.isEmpty)) {
        throw const FormatException('The selected file has no readable rows.');
      }
      if (!mounted) return;

      setState(() {
        _fileName = file.name;
        _sheets = sheets;
        _selectedSheet = sheets.keys.first;
        _isPickingFile = false;
        _error = null;
      });
      _loadSelectedSheet();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPickingFile = false;
        _error = 'Unable to read this statement: $error';
      });
    }
  }

  void _loadSelectedSheet() {
    final sheetName = _selectedSheet;
    if (sheetName == null) return;
    final rows = _sheets[sheetName] ?? [];
    if (rows.isEmpty) {
      setState(() {
        _selectedRows = [];
        _mapping = null;
        _parseResult = null;
      });
      return;
    }

    final headerIndex = BankStatementParser.detectHeaderRow(rows);
    final headers = rows[headerIndex].map((value) => value.trim()).toList();
    setState(() {
      _selectedRows = rows;
      _headerRowIndex = headerIndex;
      _mapping = BankStatementParser.detectMapping(headers);
      _lastResult = null;
    });
    _refreshPreview();
  }

  List<String> get _headers {
    if (_selectedRows.isEmpty || _headerRowIndex >= _selectedRows.length) {
      return [];
    }
    return _selectedRows[_headerRowIndex];
  }

  List<List<String>> get _dataRows =>
      _selectedRows.skip(_headerRowIndex + 1).toList();

  void _refreshPreview() {
    final mapping = _mapping;
    if (mapping == null) return;
    final result = BankStatementParser.parse(
      headers: _headers,
      rows: _dataRows,
      mapping: mapping,
    );
    setState(() => _parseResult = result);
  }

  void _updateMapping(StatementColumnMapping mapping) {
    setState(() {
      _mapping = mapping;
      _lastResult = null;
    });
    _refreshPreview();
  }

  String _money(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  Future<void> _importReviewedTransactions() async {
    final result = _parseResult;
    final accountId = _selectedAccountId;
    if (result == null || result.transactions.isEmpty || accountId == null) {
      return;
    }

    final account = _accounts.firstWhere((item) => item.id == accountId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import statement transactions?'),
        content: Text(
          'Import ${result.transactions.length} transactions into '
          '${bankAccountDisplayLabel(account.bankName, account.accountNumberLast4)}? '
          'Existing matches will be skipped. This will update the account balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isImporting = true;
      _error = null;
    });
    try {
      final imported = await BankStatementImportRepository(widget.database)
          .importTransactions(
        accountId: accountId,
        transactions: result.transactions,
      );
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _lastResult = imported;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${imported.importedCount}; skipped '
            '${imported.duplicateCount} duplicates and '
            '${imported.skippedCount} invalid rows.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _error = 'Statement import failed: $error';
      });
    }
  }

  Widget _columnDropdown({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-${value ?? -1}'),
      initialValue: value ?? -1,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: -1,
          child: Text('Not mapped'),
        ),
        ..._headers.asMap().entries.map(
          (entry) => DropdownMenuItem<int>(
            value: entry.key,
            child: Text(
              '${_columnLetter(entry.key)} · '
              '${entry.value.isEmpty ? 'Column ${entry.key + 1}' : entry.value}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (selected) => onChanged(
        selected == null || selected < 0 ? null : selected,
      ),
    );
  }

  String _columnLetter(int index) {
    var value = index + 1;
    var result = '';
    while (value > 0) {
      final remainder = (value - 1) % 26;
      result = String.fromCharCode(65 + remainder) + result;
      value = (value - 1) ~/ 26;
    }
    return result;
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAEB)),
      ),
      child: child,
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _statementNavy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import a bank statement',
            style: TextStyle(
              color: _statementNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Choose a CSV or Excel statement. Artham reads it on this device, '
            'previews the transactions and checks for duplicates before saving.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isPickingFile ? null : _pickStatement,
              style: FilledButton.styleFrom(
                backgroundColor: _statementGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isPickingFile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _isPickingFile ? 'Reading statement...' : 'Choose statement file',
              ),
            ),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.description_outlined, color: _statementGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _statementNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMappingCard() {
    final mapping = _mapping;
    if (mapping == null || _headers.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm statement columns',
            style: TextStyle(
              color: _statementNavy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check the suggested column mapping. You can change any field before importing.',
            style: TextStyle(color: Colors.black54, fontSize: 11),
          ),
          if (_sheets.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('sheet-$_selectedSheet'),
              initialValue: _selectedSheet,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Worksheet',
                border: OutlineInputBorder(),
              ),
              items: _sheets.keys.map(
                (name) => DropdownMenuItem(value: name, child: Text(name)),
              ).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSheet = value);
                _loadSelectedSheet();
              },
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('header-$_headerRowIndex'),
            initialValue: _headerRowIndex,
            decoration: const InputDecoration(
              labelText: 'Header row',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              _selectedRows.length < 10 ? _selectedRows.length : 10,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(
                  'Row ${index + 1}: '
                  '${_selectedRows[index].take(3).join(' · ')}',
                ),
              ),
            ),
            onChanged: (value) {
              if (value == null) return;
              final nextHeaders = _selectedRows[value];
              setState(() {
                _headerRowIndex = value;
                _mapping = BankStatementParser.detectMapping(nextHeaders);
                _lastResult = null;
              });
              _refreshPreview();
            },
          ),
          const SizedBox(height: 12),
          _columnDropdown(
            label: 'Transaction date (required)',
            value: mapping.dateColumn >= 0 ? mapping.dateColumn : null,
            onChanged: (value) => _updateMapping(
              mapping.copyWith(dateColumn: value ?? -1),
            ),
          ),
          const SizedBox(height: 10),
          _columnDropdown(
            label: 'Description / narration (required)',
            value: mapping.descriptionColumn >= 0
                ? mapping.descriptionColumn
                : null,
            onChanged: (value) => _updateMapping(
              mapping.copyWith(descriptionColumn: value ?? -1),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _columnDropdown(
                  label: 'Debit amount',
                  value: mapping.debitColumn,
                  onChanged: (value) => _updateMapping(
                    mapping.copyWith(
                      debitColumn: value,
                      clearDebitColumn: value == null,
                      clearAmountColumn: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _columnDropdown(
                  label: 'Credit amount',
                  value: mapping.creditColumn,
                  onChanged: (value) => _updateMapping(
                    mapping.copyWith(
                      creditColumn: value,
                      clearCreditColumn: value == null,
                      clearAmountColumn: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _columnDropdown(
            label: 'Single signed amount (optional)',
            value: mapping.amountColumn,
            onChanged: (value) => _updateMapping(
              mapping.copyWith(
                amountColumn: value,
                clearAmountColumn: value == null,
                clearDebitColumn: value != null,
                clearCreditColumn: value != null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _columnDropdown(
            label: 'Debit / Credit type (optional)',
            value: mapping.typeColumn,
            onChanged: (value) => _updateMapping(
              mapping.copyWith(
                typeColumn: value,
                clearTypeColumn: value == null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _columnDropdown(
            label: 'Reference / UTR (optional)',
            value: mapping.referenceColumn,
            onChanged: (value) => _updateMapping(
              mapping.copyWith(
                referenceColumn: value,
                clearReferenceColumn: value == null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final result = _parseResult;
    if (_mapping == null || result == null) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import preview',
            style: TextStyle(
              color: _statementNavy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (result.configurationError != null) ...[
            const SizedBox(height: 8),
            Text(
              result.configurationError!,
              style: const TextStyle(color: Color(0xFFC45D58), fontSize: 12),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _metric('READY', result.transactions.length.toString())),
                Expanded(child: _metric('SKIPPED', result.skippedRows.toString())),
                Expanded(child: _metric('ROWS', result.totalRows.toString())),
              ],
            ),
            const Divider(height: 24),
            if (result.transactions.isEmpty)
              const Text(
                'No valid transactions found. Review the column mapping and date/amount formats.',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              )
            else
              ...result.transactions.take(5).map((item) {
                final isIncome = item.transactionType == 'income';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    item.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _statementNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    '${_dateLabel(item.transactionDate)} · '
                    '${isIncome ? 'Income' : 'Expense'}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: Text(
                    '${isIncome ? '+' : '−'}${_money(item.amountPaise)}',
                    style: TextStyle(
                      color: isIncome ? _statementGreen : const Color(0xFFC45D58),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            if (result.transactions.length > 5)
              Text(
                'And ${result.transactions.length - 5} more transactions...',
                style: const TextStyle(color: Colors.black54, fontSize: 10),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destination account',
            style: TextStyle(
              color: _statementNavy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_accounts.isEmpty)
            const Text(
              'Add a bank account before importing a statement.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            DropdownButtonFormField<int>(
              key: ValueKey('account-$_selectedAccountId'),
              initialValue: _selectedAccountId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Bank account',
                border: OutlineInputBorder(),
              ),
              items: _accounts.map((account) {
                return DropdownMenuItem(
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
              onChanged: (value) => setState(() => _selectedAccountId = value),
            ),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    final result = _parseResult;
    final enabled = result != null &&
        result.configurationError == null &&
        result.transactions.isNotEmpty &&
        _selectedAccountId != null &&
        !_isImporting &&
        _lastResult == null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _importReviewedTransactions : null,
        style: FilledButton.styleFrom(
          backgroundColor: _statementGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(
          _isImporting ? 'Importing...' : 'Import reviewed transactions',
        ),
      ),
    );
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _statementBackground,
      appBar: AppBar(
        backgroundColor: _statementBackground,
        foregroundColor: _statementNavy,
        elevation: 0,
        title: const Text(
          'Import bank statement',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoadingAccounts
          ? const Center(
              child: CircularProgressIndicator(color: _statementGreen),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _buildFileCard(),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC45D58), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                _buildAccountCard(),
                if (_mapping != null) ...[
                  const SizedBox(height: 14),
                  _buildMappingCard(),
                  const SizedBox(height: 14),
                  _buildPreviewCard(),
                  const SizedBox(height: 14),
                  _buildImportButton(),
                ],
                if (_lastResult != null) ...[
                  const SizedBox(height: 12),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed: ${_lastResult!.importedCount} imported, '
                          '${_lastResult!.duplicateCount} duplicates skipped, '
                          '${_lastResult!.skippedCount} rows skipped.',
                          style: const TextStyle(
                            color: _statementNavy,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Privacy: statement files are read on this device. Artham does not upload or retain the selected file. Only transactions you confirm are saved.',
                  style: TextStyle(color: Colors.black45, fontSize: 10, height: 1.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supported formats: CSV, XLSX and legacy XLS. PDF statements are not supported in this stage.',
                  style: TextStyle(color: Colors.black45, fontSize: 10, height: 1.4),
                ),
              ],
            ),
    );
  }
}
