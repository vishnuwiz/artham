import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../data/data_export_service.dart';
import '../../data/data_import_service.dart';
import '../../theme/artham_theme.dart';
import 'backup_management_screen.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isExportExpanded = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          title: fullBackup ? 'Artham full data backup' : 'Artham transactions',
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

  Future<void> _restoreBackup([File? backupFile]) async {
    if (_isExporting) return;

    setState(() => _isExporting = true);
    try {
      late final String contents;
      if (backupFile == null) {
        final selectedFile = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (!mounted || selectedFile == null) return;
        contents = utf8.decode(await selectedFile.readAsBytes());
      } else {
        contents = await backupFile.readAsString();
      }

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
                    'Backup date: ${preview.exportedAt.toLocal()}',
                    style: const TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RestoreCountLine('Bank accounts', preview.bankAccountCount),
                  _RestoreCountLine('Transactions', preview.transactionCount),
                  _RestoreCountLine('Categories', preview.categoryCount),
                  _RestoreCountLine('Merchants', preview.merchantCount),
                  _RestoreCountLine('Budgets', preview.budgetCount),
                  _RestoreCountLine(
                    'Budget templates',
                    preview.budgetTemplateCount,
                  ),
                  _RestoreCountLine(
                    'Recurring schedules',
                    preview.recurringScheduleCount,
                  ),
                  _RestoreCountLine(
                    'Processed SMS records',
                    preview.processedSmsCount,
                  ),
                  if (preview.legacyPendingSmsImportCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'This backup also contains ${preview.legacyPendingSmsImportCount} older pending SMS review item(s). The current version cannot restore those legacy items.',
                      style: const TextStyle(
                        color: ArthamColors.debit,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Before replacing your data, Artham will automatically '
                    "save a safety copy in this app's private storage. Keep "
                    'a separate backup outside the app for additional protection.',
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

      // Do not proceed if the pre-restore safety copy cannot be written.
      await DataExportService(widget.database).createLocalSafetyBackupFile();

      final restored = await importService.restoreFullBackupJson(contents);
      if (mounted) {
        _showMessage(
          'Backup restored: ${restored.bankAccountCount} accounts and ${restored.transactionCount} transactions. A safety copy of your previous data was saved on this device. Switch to Home to refresh the dashboard.',
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

  Future<void> _restoreManagedBackup(File file) => _restoreBackup(file);

  void _openBackupManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BackupManagementScreen(
          database: widget.database,
          onRestoreBackup: _restoreManagedBackup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('settings-scroll-view'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const _SettingsSectionLabel('DATA & CUSTOMIZATION'),
            const SizedBox(height: 12),
            _SettingsNavigationCard(
              key: const Key('settings-categories-row'),
              tapKey: const Key('manage-categories-button'),
              icon: Icons.category_outlined,
              accent: const Color(0xFFD19BFF),
              title: 'Categories',
              subtitle: 'Add, rename, recolour and hide categories.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CategoriesScreen(database: widget.database),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildDataExportCard(),
            const SizedBox(height: 24),
            const _SettingsSectionLabel('APP & STORAGE'),
            const SizedBox(height: 12),
            _SettingsNavigationCard(
              key: const Key('settings-backup-management-row'),
              icon: Icons.storage_rounded,
              accent: const Color(0xFF9FC6FF),
              title: 'Backup management',
              subtitle: 'View backups and manage storage.',
              onTap: _openBackupManagement,
            ),
            const SizedBox(height: 24),
            const _SettingsSectionLabel('PRIVACY'),
            const SizedBox(height: 12),
            _buildPrivacyCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 108,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -18,
            right: -20,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: 150,
                  height: 86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(64),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x55D3BCFF),
                        Color(0x1CB9A5F5),
                        Color(0x08FFFFFF),
                      ],
                    ),
                    border: Border.all(color: const Color(0x35FFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x334D3D8B),
                        blurRadius: 26,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: ArthamColors.text,
                    fontSize: 32,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Manage your Artham experience',
                  style: TextStyle(
                    color: ArthamColors.muted.withValues(alpha: 0.96),
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataExportCard() {
    return GlassPanel(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('settings-export-header'),
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  setState(() => _isExportExpanded = !_isExportExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 3, 2, 7),
                child: Row(
                  children: [
                    const _SettingsIconBadge(
                      icon: Icons.file_download_outlined,
                      accent: Color(0xFF9FC6FF),
                      size: 58,
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export your data',
                            style: TextStyle(
                              color: ArthamColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Export transactions or create a JSON backup of your Artham data.',
                            style: TextStyle(
                              color: ArthamColors.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isExportExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ArthamColors.text,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _isExportExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildExportContents(),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (_isExporting) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              color: ArthamColors.lavender,
              minHeight: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportContents() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExportBlock(
            icon: Icons.description_outlined,
            accent: ArthamColors.mint,
            title: 'Transactions · CSV',
            description: 'Export your transactions as a spreadsheet.',
            fullBackup: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: ArthamColors.line),
          ),
          _buildExportBlock(
            icon: Icons.code_rounded,
            accent: ArthamColors.peach,
            title: 'Full backup · JSON',
            description: 'Accounts, categories, budgets and more.',
            fullBackup: true,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('restore-json-backup-button'),
            onPressed: _isExporting ? null : _restoreBackup,
            style: OutlinedButton.styleFrom(
              foregroundColor: ArthamColors.debit,
              side: BorderSide(
                color: ArthamColors.debit.withValues(alpha: 0.75),
              ),
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.history_rounded, size: 21),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Restore from JSON backup',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 23),
              ],
            ),
          ),
          const SizedBox(height: 9),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: ArthamColors.muted, size: 14),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'JSON backups are not encrypted. Store backup files securely.',
                  style: TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportBlock({
    required IconData icon,
    required Color accent,
    required String title,
    required String description,
    required bool fullBackup,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionSize = constraints.maxWidth < 300 ? 40.0 : 44.0;
        final actionGap = constraints.maxWidth < 300 ? 6.0 : 8.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SettingsIconBadge(icon: icon, accent: accent, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ArthamColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: actionGap),
            _buildExportActionButton(
              fullBackup: fullBackup,
              share: true,
              size: actionSize,
            ),
            SizedBox(width: actionGap),
            _buildExportActionButton(
              fullBackup: fullBackup,
              share: false,
              size: actionSize,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportActionButton({
    required bool fullBackup,
    required bool share,
    required double size,
  }) {
    final label = share
        ? (fullBackup ? 'Share JSON' : 'Share CSV')
        : (fullBackup ? 'Save JSON' : 'Save CSV');
    final key = share
        ? (fullBackup ? 'share-json-button' : 'share-csv-button')
        : (fullBackup ? 'save-json-button' : 'save-csv-button');

    final buttonStyle = share
        ? OutlinedButton.styleFrom(
            foregroundColor: ArthamColors.lavender,
            side: BorderSide(
              color: ArthamColors.lavender.withValues(alpha: 0.9),
            ),
            padding: EdgeInsets.zero,
            minimumSize: Size(size, size),
            maximumSize: Size(size, size),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          )
        : FilledButton.styleFrom(
            backgroundColor: ArthamColors.lavender,
            foregroundColor: ArthamColors.onAccent,
            padding: EdgeInsets.zero,
            minimumSize: Size(size, size),
            maximumSize: Size(size, size),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          );

    return Tooltip(
      message: label,
      child: SizedBox(
        width: size,
        height: size,
        child: share
            ? OutlinedButton(
                key: Key(key),
                onPressed: _isExporting
                    ? null
                    : () => _shareExportFile(fullBackup: fullBackup),
                style: buttonStyle,
                child: const Icon(Icons.share_rounded, size: 20),
              )
            : FilledButton(
                key: Key(key),
                onPressed: _isExporting
                    ? null
                    : () => _saveExportFile(fullBackup: fullBackup),
                style: buttonStyle,
                child: const Icon(Icons.download_rounded, size: 21),
              ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return GlassPanel(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsIconBadge(
            icon: Icons.shield_outlined,
            accent: ArthamColors.mint,
            size: 44,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data stays under your control',
                  style: TextStyle(
                    color: ArthamColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Artham does not scan your SMS inbox. Import starts only when you paste or share an alert from Activity. You review the parsed fields before saving, and the original message text is not retained.',
                  style: TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String text;

  const _SettingsSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: ArthamColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.25,
        ),
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;

  const _SettingsIconBadge({
    required this.icon,
    required this.accent,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.19),
        borderRadius: BorderRadius.circular(size * 0.31),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: accent, size: size * 0.48),
    );
  }
}

class _SettingsNavigationCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Key? tapKey;

  const _SettingsNavigationCard({
    super.key,
    this.tapKey,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(23),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tapKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                _SettingsIconBadge(icon: icon, accent: accent, size: 54),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: ArthamColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ArthamColors.text,
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreCountLine extends StatelessWidget {
  final String label;
  final int count;

  const _RestoreCountLine(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            count.toString(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
