import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../data/data_export_service.dart';
import '../../data/repositories/sms_import_repository.dart';
import '../../data/repositories/transaction_repository.dart';

const MethodChannel _automaticSmsChannel = MethodChannel(
  'artham/automatic_sms',
);

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const SettingsScreen({
    super.key,
    required this.database,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final SmsImportRepository _smsRepository;

  bool _isLoading = true;
  bool _isExporting = false;
  bool _isSupported = false;
  bool _permissionGranted = false;
  bool _isEnabled = false;
  int? _defaultAccountId;
  List<BankAccount> _accounts = [];
  List<Category> _categories = [];
  List<PendingSmsImport> _pendingImports = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _smsRepository = SmsImportRepository(widget.database);
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isLoading) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (!mounted) return;
      setState(() {
        _isSupported = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transactionRepository = TransactionRepository(widget.database);
      await transactionRepository.seedDefaultCategories();

      final accounts = await transactionRepository.getActiveAccounts();
      final incomeCategories =
          await transactionRepository.getCategories('income');
      final expenseCategories =
          await transactionRepository.getCategories('expense');
      await _smsRepository.ensurePendingImportsTable();
      final pendingImports = await _smsRepository.getPendingImports();
      final status = await _automaticSmsChannel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _categories = [...incomeCategories, ...expenseCategories];
        _pendingImports = pendingImports;
        _isSupported = status?['supported'] == true;
        _permissionGranted = status?['permissionGranted'] == true;
        _isEnabled = status?['enabled'] == true && _permissionGranted;
        _defaultAccountId = (status?['defaultAccountId'] as num?)?.toInt();
        _isLoading = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _isSupported = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load SMS import settings: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAutomaticImport(bool enable) async {
    if (!enable) {
      try {
        await _automaticSmsChannel.invokeMethod<bool>(
          'setEnabled',
          {'enabled': false},
        );
        if (!mounted) return;
        setState(() => _isEnabled = false);
      } catch (error) {
        _showMessage('Unable to turn off automatic import: $error');
      }
      return;
    }

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable automatic SMS import?'),
        content: const Text(
          'Artham will inspect newly received SMS messages on this Android '
          'device to identify bank and UPI transaction alerts. Recognised '
          'transactions will be saved automatically to your local Artham '
          'database. OTPs and unrelated messages are ignored. The original '
          'SMS text is not saved or uploaded by this feature. You can turn '
          'automatic import off at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (consent != true || !mounted) return;

    try {
      final granted = await _automaticSmsChannel.invokeMethod<bool>(
        'requestPermission',
      );
      if (granted != true) {
        _showMessage(
          'SMS permission was not granted. Automatic import remains off.',
        );
        await _loadSettings();
        return;
      }

      await _automaticSmsChannel.invokeMethod<bool>(
        'setEnabled',
        {'enabled': true},
      );

      if (!mounted) return;
      setState(() {
        _permissionGranted = true;
        _isEnabled = true;
        _error = null;
      });

      if (_accounts.length > 1 && _defaultAccountId == null) {
        _showMessage(
          'Choose a default account below for SMS alerts that do not identify '
          'a specific account.',
        );
      }
    } catch (error) {
      _showMessage('Could not enable automatic SMS import: $error');
      await _loadSettings();
    }
  }

  Future<void> _setDefaultAccount(int? accountId) async {
    try {
      await _automaticSmsChannel.invokeMethod<bool>(
        'setDefaultAccountId',
        {'accountId': accountId},
      );
      if (!mounted) return;
      setState(() => _defaultAccountId = accountId);
    } catch (error) {
      _showMessage('Unable to save the default account: $error');
    }
  }

  Future<void> _importPending(
    PendingSmsImport pending,
    int accountId,
  ) async {
    final category = _categories.where(
      (item) =>
          item.type == pending.transactionType &&
          item.name.toLowerCase() == pending.suggestedCategory.toLowerCase(),
    );
    final fallbackName = pending.transactionType == 'income'
        ? 'Other Income'
        : 'Other Expense';
    final fallback = _categories.where(
      (item) =>
          item.type == pending.transactionType &&
          item.name == fallbackName,
    );
    final categoryId = category.isNotEmpty
        ? category.first.id
        : (fallback.isNotEmpty ? fallback.first.id : null);

    if (categoryId == null) {
      _showMessage('No matching transaction category is available.');
      return;
    }

    try {
      await _smsRepository.importTransaction(
        fingerprint: pending.fingerprint,
        accountId: accountId,
        categoryId: categoryId,
        amountPaise: pending.amountPaise,
        transactionType: pending.transactionType,
        transactionDate: pending.transactionDate,
        description: pending.description,
        referenceNumber: pending.referenceNumber,
      );
      await _smsRepository.deletePendingImport(pending.id);
      if (!mounted) return;
      setState(() {
        _pendingImports.removeWhere((item) => item.id == pending.id);
      });
      _showMessage('Transaction imported successfully.');
    } on DuplicateSmsImportException {
      await _smsRepository.deletePendingImport(pending.id);
      if (!mounted) return;
      setState(() {
        _pendingImports.removeWhere((item) => item.id == pending.id);
      });
      _showMessage('This SMS was already imported. Duplicate removed.');
    } catch (error) {
      _showMessage('Unable to import this transaction: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _shareExportFile({required bool fullBackup}) async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      final exportService = DataExportService(widget.database);
      final file = fullBackup
          ? await exportService.createFullBackupFile()
          : await exportService.createTransactionsCsvFile();

      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final shareOrigin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          title: fullBackup
              ? 'Artham full data backup'
              : 'Artham transactions',
          text: fullBackup
              ? 'Artham JSON backup. This file contains personal financial data; '
                  'store and share it securely.'
              : 'Artham transaction history in CSV format.',
          sharePositionOrigin: shareOrigin,
        ),
      );

      if (mounted) {
        _showMessage(
          'Export file prepared. Choose an app or save location in the share sheet.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to create the export: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF142B35),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7F8),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSettings,
            tooltip: 'Refresh settings',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _buildAutomaticSmsCard(),
                if (_pendingImports.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPendingImportsCard(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 18),
                _buildDataExportCard(),
                const SizedBox(height: 18),
                _buildPrivacyCard(),
              ],
            ),
    );
  }

  Widget _buildAutomaticSmsCard() {
    if (!_isSupported) {
      return _SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SectionHeading(
              icon: Icons.sms_outlined,
              title: 'Automatic SMS import',
            ),
            SizedBox(height: 12),
            Text(
              'Automatic incoming-SMS import is available on Android only. '
              'On iPhone, use the existing paste/share import option.',
              style: TextStyle(
                color: Color(0xFF52636A),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.sms_outlined,
            title: 'Automatic SMS import',
          ),
          const SizedBox(height: 6),
          const Text(
            'Automatically detect new bank and UPI debit/credit alerts. When a '
            'message includes account digits, Artham matches the final four '
            'digits to your saved bank accounts.',
            style: TextStyle(
              color: Color(0xFF52636A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Enable automatic import',
              style: TextStyle(
                color: Color(0xFF142B35),
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _permissionGranted
                  ? (_isEnabled
                      ? 'Listening for new incoming SMS alerts'
                      : 'SMS permission granted; import is turned off')
                  : 'Permission required',
              style: const TextStyle(
                color: Color(0xFF68777D),
                fontSize: 12,
              ),
            ),
            value: _isEnabled,
            onChanged: _accounts.isEmpty ? null : _toggleAutomaticImport,
            activeTrackColor: const Color(0xFF13866A),
          ),
          if (_accounts.isNotEmpty) ...[
            const Divider(height: 22),
            const Text(
              'Default bank account',
              style: TextStyle(
                color: Color(0xFF142B35),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Used only when the message has no account suffix and its sender cannot '
              'identify a saved account. A suffix that is unknown or shared by '
              'multiple accounts waits for your review.',
              style: TextStyle(
                color: Color(0xFF68777D),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _accounts.any(
                (account) => account.id == _defaultAccountId,
              )
                  ? _defaultAccountId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              hint: const Text('Select default account'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Do not use a default account'),
                ),
                ..._accounts.map(
                  (account) => DropdownMenuItem<int?>(
                    value: account.id,
                    child: Text(
                      bankAccountDisplayLabel(account.bankName, account.accountNumberLast4),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _setDefaultAccount,
            ),
          ],
          if (_accounts.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Add a bank account before enabling automatic transaction import.',
              style: TextStyle(
                color: Color(0xFFB45C28),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingImportsCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.pending_actions_rounded,
            title: 'SMS transactions waiting for account',
          ),
          const SizedBox(height: 6),
          Text(
            '${_pendingImports.length} transaction(s) could not be assigned '
            'automatically. Choose the correct bank account to finish importing.',
            style: const TextStyle(
              color: Color(0xFF52636A),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingImports.map(
            (pending) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingSmsImportTile(
                pending: pending,
                accounts: _accounts,
                onImport: (accountId) => _importPending(pending, accountId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.file_download_outlined,
            title: 'Export your data',
          ),
          const SizedBox(height: 8),
          const Text(
            'Export your transaction history for spreadsheets or create a '
            'JSON backup containing your accounts, transactions, categories, '
            'merchants, budgets and recurring schedules.',
            style: TextStyle(
              color: Color(0xFF52636A),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Exports are generated on this device. JSON backups are not '
            'encrypted and contain personal financial information; store '
            'them securely. Restore is not included yet.',
            style: TextStyle(
              color: Color(0xFF68777D),
              fontSize: 11,
              height: 1.45,
            ),
          ),
          if (_isExporting) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(
              color: Color(0xFF13866A),
              minHeight: 3,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _shareExportFile(fullBackup: false),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF13866A),
                ),
              ),
              FilledButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _shareExportFile(fullBackup: true),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Full JSON backup'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF13866A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeading(
            icon: Icons.shield_outlined,
            title: 'Your SMS privacy',
          ),
          SizedBox(height: 10),
          _PrivacyLine(
            text: 'Only newly received SMS messages are examined; Artham does not scan your existing inbox.',
          ),
          _PrivacyLine(
            text: 'The original message body is not stored in the transaction database.',
          ),
          _PrivacyLine(
            text: 'Transaction parsing and saving happen on this device. This feature does not upload SMS content.',
          ),
          _PrivacyLine(
            text: 'Duplicate alerts are ignored using a local message fingerprint.',
          ),
          _PrivacyLine(
            text: 'You can disable automatic import here or revoke SMS permission in Android settings.',
          ),
        ],
      ),
    );
  }
}

class _PendingSmsImportTile extends StatefulWidget {
  final PendingSmsImport pending;
  final List<BankAccount> accounts;
  final Future<void> Function(int accountId) onImport;

  const _PendingSmsImportTile({
    required this.pending,
    required this.accounts,
    required this.onImport,
  });

  @override
  State<_PendingSmsImportTile> createState() => _PendingSmsImportTileState();
}

class _PendingSmsImportTileState extends State<_PendingSmsImportTile> {
  int? _selectedAccountId;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    final isIncome = pending.transactionType == 'income';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE5EAEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pending.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF142B35),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}₹${(pending.amountPaise / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  color: isIncome
                      ? const Color(0xFF13866A)
                      : const Color(0xFFC45D58),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${pending.transactionType.toUpperCase()} · '
            '${pending.transactionDate.day.toString().padLeft(2, '0')}/'
            '${pending.transactionDate.month.toString().padLeft(2, '0')}/'
            '${pending.transactionDate.year}',
            style: const TextStyle(
              color: Color(0xFF68777D),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Sender: ${pending.sender.isEmpty ? 'Unknown' : pending.sender} · '
            'Suggested: ${pending.suggestedCategory}',
            style: const TextStyle(
              color: Color(0xFF68777D),
              fontSize: 11,
            ),
          ),
          if (pending.referenceNumber != null) ...[
            const SizedBox(height: 3),
            Text(
              'Reference: ${pending.referenceNumber}',
              style: const TextStyle(
                color: Color(0xFF68777D),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Choose bank account',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: widget.accounts
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
            onChanged: _isImporting
                ? null
                : (value) => setState(() => _selectedAccountId = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedAccountId == null ||
                      _isImporting ||
                      widget.accounts.isEmpty
                  ? null
                  : () async {
                      setState(() => _isImporting = true);
                      try {
                        await widget.onImport(_selectedAccountId!);
                      } finally {
                        if (mounted) {
                          setState(() => _isImporting = false);
                        }
                      }
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Import transaction'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF13866A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECEE)),
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeading({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF13866A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF142B35),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  final String text;

  const _PrivacyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.check_circle_outline,
              size: 15,
              color: Color(0xFF13866A),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF52636A),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
