import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../data/data_export_service.dart';
import '../../data/data_import_service.dart';
import '../../theme/artham_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const SettingsScreen({
    super.key,
    required this.database,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;

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

  /// Opens the native Save As document picker (Android/iOS).
  /// Unlike the share sheet, this lets users choose a storage location.
  Future<void> _saveExportFile({required bool fullBackup}) async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      final exportService = DataExportService(widget.database);
      final content = fullBackup
          ? await exportService.buildFullBackupJson()
          : await exportService.buildTransactionsCsv();
      final bytes = Uint8List.fromList(
        utf8.encode(fullBackup ? content : '\uFEFF$content'),
      );
      final fileName = fullBackup
          ? 'artham_backup.json'
          : 'artham_transactions.csv';

      final savedUri = await FilePicker.saveFile(
        dialogTitle: fullBackup
            ? 'Save Artham JSON backup'
            : 'Save Artham transaction CSV',
        fileName: fileName,
        bytes: bytes,
        mimeType: fullBackup ? 'application/json' : 'text/csv',
      );

      if (!mounted) return;
      if (savedUri == null) {
        _showMessage('Save cancelled.');
      } else {
        _showMessage(
          fullBackup
              ? 'JSON backup saved successfully.'
              : 'Transaction CSV saved successfully.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to save the export: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      final selectedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (!mounted || selectedFile == null) return;

      final bytes = await selectedFile.readAsBytes();

      final contents = utf8.decode(bytes);
      final importService = DataImportService(widget.database);
      final preview = importService.inspectFullBackupJson(contents);

      if (!mounted) return;
      final shouldRestore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Restore this backup?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will replace the Artham data currently stored on '
                    'this device with the contents of the selected backup.',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Backup date: \${preview.exportedAt.toLocal()}',
                    style: const TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _restoreCountLine('Bank accounts', preview.bankAccountCount),
                  _restoreCountLine('Transactions', preview.transactionCount),
                  _restoreCountLine('Categories', preview.categoryCount),
                  _restoreCountLine('Merchants', preview.merchantCount),
                  _restoreCountLine('Budgets', preview.budgetCount),
                  _restoreCountLine(
                    'Budget templates',
                    preview.budgetTemplateCount,
                  ),
                  _restoreCountLine(
                    'Recurring schedules',
                    preview.recurringScheduleCount,
                  ),
                  _restoreCountLine(
                    'Processed SMS records',
                    preview.processedSmsCount,
                  ),
                  if (preview.legacyPendingSmsImportCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'This backup also contains \${preview.legacyPendingSmsImportCount} older pending SMS review item(s). The current version cannot restore those legacy items.',
                      style: const TextStyle(
                        color: ArthamColors.debit,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Make sure you have a separate backup of your current '
                    'data before continuing. This action cannot be undone.',
                    style: TextStyle(
                      color: ArthamColors.debit,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: ArthamColors.debit,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Replace local data'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldRestore != true) return;

      final restored = await importService.restoreFullBackupJson(contents);
      if (mounted) {
        _showMessage(
          'Backup restored: \${restored.bankAccountCount} accounts and \${restored.transactionCount} transactions. Switch to Home to refresh the dashboard.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to restore the backup: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _restoreCountLine(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: ArthamColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _buildDataExportCard(),
          const SizedBox(height: 18),
          _buildSmsPrivacyCard(),
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
              color: ArthamColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Exports are generated on this device. JSON backups are not '
            'encrypted and contain personal financial information; store '
            'them securely. Restoring replaces current local data, so keep '
            'a backup before importing another one.',
            style: TextStyle(
              color: ArthamColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          if (_isExporting) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(
              color: ArthamColors.lavender,
              minHeight: 3,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Transaction history · CSV',
            style: TextStyle(
              color: ArthamColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _shareExportFile(fullBackup: false),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ArthamColors.lavender,
                ),
              ),
              FilledButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _saveExportFile(fullBackup: false),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save CSV'),
                style: FilledButton.styleFrom(
                  backgroundColor: ArthamColors.lavender,
                  foregroundColor: ArthamColors.onAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: ArthamColors.line),
          const SizedBox(height: 12),
          const Text(
            'Complete backup · JSON',
            style: TextStyle(
              color: ArthamColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _shareExportFile(fullBackup: true),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share JSON'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ArthamColors.lavender,
                ),
              ),
              FilledButton.icon(
                onPressed: _isExporting
                    ? null
                    : () => _saveExportFile(fullBackup: true),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save JSON'),
                style: FilledButton.styleFrom(
                  backgroundColor: ArthamColors.lavender,
                  foregroundColor: ArthamColors.onAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isExporting ? null : _restoreBackup,
            icon: const Icon(Icons.settings_backup_restore_rounded),
            label: const Text('Restore from JSON backup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ArthamColors.debit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsPrivacyCard() {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeading(
            icon: Icons.shield_outlined,
            title: 'SMS privacy',
          ),
          SizedBox(height: 10),
          _PrivacyLine(
            text: 'Artham does not read incoming SMS messages or scan your SMS inbox.',
          ),
          _PrivacyLine(
            text: 'SMS import is initiated by you: paste or share a selected message from Activity > Import SMS.',
          ),
          _PrivacyLine(
            text: 'You can review the parsed transaction before saving it to your local database.',
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
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArthamColors.line),
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
        Icon(icon, color: ArthamColors.lavender),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ArthamColors.text,
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
              color: ArthamColors.lavender,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ArthamColors.muted,
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
