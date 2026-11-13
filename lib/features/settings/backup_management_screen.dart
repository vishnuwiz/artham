import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/backup_manager.dart';
import '../../theme/artham_theme.dart';

class BackupManagementScreen extends StatefulWidget {
  final AppDatabase database;
  final Future<void> Function(File file) onRestoreBackup;

  const BackupManagementScreen({
    super.key,
    required this.database,
    required this.onRestoreBackup,
  });

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  late final BackupManagerService _backupManager;
  BackupSettings? _settings;
  List<BackupHistoryEntry> _history = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _backupManager = BackupManagerService(widget.database);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _backupManager.loadSettings();
      final history = await _backupManager.listBackupHistory();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _history = history;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load backup information: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings(
    BackupSettings settings, {
    bool checkScheduleNow = false,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _backupManager.saveSettings(settings);
      await _backupManager.pruneAutomaticBackups();
      if (checkScheduleNow && settings.automaticBackupsEnabled) {
        await _backupManager.maybeCreateScheduledBackup();
      }
      await _loadData();
      if (checkScheduleNow && settings.automaticBackupsEnabled && mounted) {
        _showMessage('Automatic backup settings saved.');
      }
    } catch (error) {
      if (mounted) _showMessage('Unable to update backup settings: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _createManualBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _backupManager.createManualBackup();
      await _loadData();
      if (mounted) _showMessage('A local backup was created successfully.');
    } catch (error) {
      if (mounted) _showMessage('Unable to create a backup: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteBackup(BackupHistoryEntry entry) async {
    if (_isBusy) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: const Text(
          'This permanently removes the selected backup file from this device. '
          'It does not change your current Artham data.',
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
            child: const Text('Delete backup'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await _backupManager.deleteBackup(entry);
      await _loadData();
      if (mounted) _showMessage('Backup deleted.');
    } catch (error) {
      if (mounted) _showMessage('Unable to delete the backup: $error');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreBackup(BackupHistoryEntry entry) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await widget.onRestoreBackup(entry.file);
      await _loadData();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Backup management',
          style: TextStyle(
            color: ArthamColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh backup history',
            onPressed: _isBusy ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _buildAutomationCard(),
                const SizedBox(height: 18),
                _buildHistoryCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: ArthamColors.debit),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAutomationCard() {
    final settings = _settings ?? const BackupSettings();
    return _BackupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackupHeading(
            icon: Icons.autorenew_rounded,
            title: 'Automatic backups',
          ),
          const SizedBox(height: 8),
          const Text(
            'Artham checks the schedule when you open the app or return to it. '
            'A backup is created when the selected interval has elapsed.',
            style: TextStyle(
              color: ArthamColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            key: const Key('automatic-backups-switch'),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: ArthamColors.lavender,
            title: const Text(
              'Enable automatic backups',
              style: TextStyle(
                color: ArthamColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              settings.automaticBackupsEnabled
                  ? 'Your data is backed up on this device.'
                  : 'Automatic backups are currently off.',
              style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
            ),
            value: settings.automaticBackupsEnabled,
            onChanged: _isBusy
                ? null
                : (enabled) => _updateSettings(
                    settings.copyWith(automaticBackupsEnabled: enabled),
                    checkScheduleNow: enabled,
                  ),
          ),
          if (settings.automaticBackupsEnabled) ...[
            const Divider(color: ArthamColors.line),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Backup frequency',
                    style: TextStyle(
                      color: ArthamColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                DropdownButton<BackupFrequency>(
                  key: const Key('backup-frequency-dropdown'),
                  value: settings.frequency,
                  items: BackupFrequency.values
                      .map(
                        (frequency) => DropdownMenuItem(
                          value: frequency,
                          child: Text(frequency.label),
                        ),
                      )
                      .toList(),
                  onChanged: _isBusy
                      ? null
                      : (frequency) {
                          if (frequency == null) return;
                          _updateSettings(
                            settings.copyWith(frequency: frequency),
                          );
                        },
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Keep automatic backups',
                    style: TextStyle(
                      color: ArthamColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                DropdownButton<int>(
                  key: const Key('backup-retention-dropdown'),
                  value: settings.maxAutomaticBackups,
                  items: const [5, 10, 20]
                      .map(
                        (count) => DropdownMenuItem(
                          value: count,
                          child: Text('Last $count'),
                        ),
                      )
                      .toList(),
                  onChanged: _isBusy
                      ? null
                      : (count) {
                          if (count == null) return;
                          _updateSettings(
                            settings.copyWith(maxAutomaticBackups: count),
                          );
                        },
                ),
              ],
            ),
            if (settings.lastAutomaticBackupAt != null)
              Text(
                'Last automatic backup: ${_formatDate(settings.lastAutomaticBackupAt!)}',
                style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('create-backup-now-button'),
              onPressed: _isBusy ? null : _createManualBackup,
              icon: const Icon(Icons.backup_rounded),
              label: const Text('Create backup now'),
              style: FilledButton.styleFrom(
                backgroundColor: ArthamColors.lavender,
                foregroundColor: ArthamColors.onAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Backups stay in this device’s app storage. They are not encrypted '
            'or uploaded to cloud storage. Save a separate copy outside the '
            'app for protection if this device is lost or reset.',
            style: TextStyle(
              color: ArthamColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return _BackupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackupHeading(
            icon: Icons.history_rounded,
            title: 'Backup history',
          ),
          const SizedBox(height: 6),
          Text(
            '${_history.length} saved backup${_history.length == 1 ? '' : 's'} on this device',
            style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'No local backups yet. Create one to start your history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                ),
              ),
            )
          else
            ..._history.map(_buildHistoryItem),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BackupHistoryEntry entry) {
    final color = entry.kind == BackupKind.restoreSafety
        ? ArthamColors.debit
        : ArthamColors.lavender;
    return Container(
      key: ValueKey(entry.file.path),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ArthamColors.line)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              entry.kind == BackupKind.restoreSafety
                  ? Icons.shield_outlined
                  : Icons.backup_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind.label,
                  style: const TextStyle(
                    color: ArthamColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(entry.createdAt)} · ${_formatBytes(entry.sizeBytes)}',
                  style: const TextStyle(
                    color: ArthamColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restore this backup',
            visualDensity: VisualDensity.compact,
            onPressed: _isBusy ? null : () => _restoreBackup(entry),
            icon: const Icon(
              Icons.settings_backup_restore_rounded,
              color: ArthamColors.lavender,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Delete this backup',
            visualDensity: VisualDensity.compact,
            onPressed: _isBusy ? null : () => _deleteBackup(entry),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: ArthamColors.muted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _BackupCard extends StatelessWidget {
  final Widget child;

  const _BackupCard({required this.child});

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

class _BackupHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _BackupHeading({required this.icon, required this.title});

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
