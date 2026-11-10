import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../data/data_export_service.dart';

class DataExportScreen extends StatefulWidget {
  final AppDatabase database;

  const DataExportScreen({
    super.key,
    required this.database,
  });

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  late final DataExportService _exportService;

  bool _useDateRange = false;
  bool _isExporting = false;
  DateTime? _startDate;
  DateTime? _endDate;

  static const Color _background = Color(0xFFF5F7F8);
  static const Color _ink = Color(0xFF142B35);
  static const Color _muted = Color(0xFF52636A);
  static const Color _green = Color(0xFF13866A);

  @override
  void initState() {
    super.initState();
    _exportService = DataExportService(widget.database);
  }

  bool get _dateRangeIsValid {
    if (!_useDateRange) return true;
    if (_startDate == null || _endDate == null) return false;
    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
    );
    return !start.isAfter(end);
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _startDate : _endDate;
    final initialDate = current ??
        (start
            ? DateTime(now.year, now.month, 1)
            : DateTime(now.year, now.month, now.day));
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: start ? 'Select start date' : 'Select end date',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<bool> _confirmExport() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export personal financial data?'),
            content: const Text(
              'The export can contain bank names, masked account digits, '
              'transaction descriptions, notes and references, along with '
              'your financial records. Artham prepares the file on this '
              'device. The app does not upload it, but the destination you '
              'choose in the share sheet will receive the file. Continue '
              'only with a destination you trust.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _export({required bool backup}) async {
    if (_isExporting) return;
    if (!backup && !_dateRangeIsValid) {
      _showMessage('Choose valid start and end dates before exporting.');
      return;
    }

    final confirmed = await _confirmExport();
    if (!confirmed || !mounted) return;

    setState(() => _isExporting = true);
    try {
      final file = backup
          ? await _exportService.exportFullFinancialBackup()
          : await _exportService.exportTransactionsCsv(
              startDate: _useDateRange ? _startDate : null,
              endDate: _useDateRange ? _endDate : null,
            );

      if (!mounted) return;

      final renderObject = context.findRenderObject();
      final box = renderObject is RenderBox ? renderObject : null;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;

      final result = await SharePlus.instance.share(
        ShareParams(
          title: file.fileName,
          text: backup
              ? 'Artham financial backup'
              : 'Artham transaction export',
          files: [
            XFile.fromData(Uint8List.fromList(file.bytes), mimeType: file.mimeType),
          ],
          fileNameOverrides: [file.fileName],
          sharePositionOrigin: origin,
        ),
      );

      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        _showMessage(
          '${file.recordCount} record(s) included. Export shared successfully.',
        );
      } else if (result.status == ShareResultStatus.dismissed) {
        _showMessage('Export cancelled. No file was shared.');
      } else {
        _showMessage(
          'Share destination did not confirm completion. You can try again.',
        );
      }
    } catch (error) {
      _showMessage('Unable to create the export: $error');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _dateLabel(DateTime? date, String emptyLabel) {
    if (date == null) return emptyLabel;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Export data',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: _background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const Text(
            'Take your financial data with you',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a spreadsheet-friendly transaction file or a portable '
            'backup of your Artham financial records.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          _exportCard(
            icon: Icons.table_chart_outlined,
            title: 'Transactions CSV',
            description:
                'Export income, expenses and transfers. Open the CSV in Excel, '
                'Google Sheets or another spreadsheet app.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _useDateRange,
                  onChanged: _isExporting
                      ? null
                      : (enabled) {
                          final now = DateTime.now();
                          setState(() {
                            _useDateRange = enabled;
                            if (enabled) {
                              _startDate ??= DateTime(now.year, now.month, 1);
                              _endDate ??= DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                            }
                          });
                        },
                  title: const Text(
                    'Limit export to a date range',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_useDateRange) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () => _pickDate(start: true),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          'From ${_dateLabel(_startDate, 'Select date')}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isExporting
                            ? null
                            : () => _pickDate(start: false),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          'To ${_dateLabel(_endDate, 'Select date')}',
                        ),
                      ),
                    ],
                  ),
                  if (!_dateRangeIsValid) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Select both dates. The start date must be on or before the end date.',
                      style: TextStyle(
                        color: Color(0xFFB45C28),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _isExporting ? null : () => _export(backup: false),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Export transactions (CSV)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _exportCard(
            icon: Icons.backup_outlined,
            title: 'Full financial backup',
            description:
                'Create a JSON backup containing your bank accounts, '
                'categories, merchants, transactions, budgets, budget '
                'templates and recurring schedules.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amounts are stored as integer paise to preserve exact values. '
                  'SMS processing fingerprints and the pending SMS review '
                  'queue are excluded.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isExporting ? null : () => _export(backup: true),
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Export full backup (JSON)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _exportCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Your data stays on this device',
            description:
                'Files are generated from the local Artham database and '
                'passed to the system share sheet only after you confirm. '
                'Choose a trusted app or a secure location to keep your export.',
          ),
          if (_isExporting) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: _green),
            ),
          ],
        ],
      ),
    );
  }

  Widget _exportCard({
    required IconData icon,
    required String title,
    required String description,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8ECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _green, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
