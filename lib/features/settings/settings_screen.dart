import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
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

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isSupported = false;
  bool _permissionGranted = false;
  bool _isEnabled = false;
  int? _defaultAccountId;
  List<BankAccount> _accounts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

    try {
      final accounts = await TransactionRepository(
        widget.database,
      ).getActiveAccounts();
      final status = await _automaticSmsChannel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isSupported = status?['supported'] == true;
        _permissionGranted = status?['permissionGranted'] == true;
        _isEnabled = status?['enabled'] == true;
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                _buildAutomaticSmsCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
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
            'Automatically detect new bank and UPI debit/credit alerts and '
            'add recognised transactions to Artham.',
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
          if (_accounts.length > 1) ...[
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
              'Used only when an SMS does not clearly identify an account. '
              'An account number suffix or a clear bank match takes priority.',
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
                      '${account.bankName} · ${account.accountName}',
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
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF142B35),
            fontWeight: FontWeight.w800,
            fontSize: 16,
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
