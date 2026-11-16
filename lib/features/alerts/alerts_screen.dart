import 'package:material_ui/material_ui.dart';

import '../../data/alerts/alert_center.dart';
import '../../data/alerts/alert_store.dart';
import '../../data/alerts/app_alert.dart';
import '../../data/app_database.dart';
import '../../data/backup_manager.dart';
import '../../theme/artham_theme.dart';

/// Everything Artham wants the user to notice: budget overruns, recurring
/// payments that are due, backup reminders and monthly summaries.
class AlertsScreen extends StatefulWidget {
  final AppDatabase database;
  final AlertCenter? center;
  final DateTime Function()? clock;

  const AlertsScreen({
    super.key,
    required this.database,
    this.center,
    this.clock,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertState? _state;
  bool _isBackingUp = false;

  AlertCenter get _center => widget.center ?? AlertCenter.instance;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Show what is stored straight away, then bring it up to date.
    final stored = await _center.load();
    if (mounted) setState(() => _state = stored);
    await _center.refresh(widget.database);
    final fresh = await _center.load();
    if (mounted) setState(() => _state = fresh);
  }

  Future<void> _reload() async {
    final fresh = await _center.load();
    if (mounted) setState(() => _state = fresh);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(AppAlert alert) async {
    if (alert.isRead) return;
    await _center.markRead(alert.key);
    await _reload();
  }

  Future<void> _markAllRead() async {
    await _center.markAllRead();
    await _reload();
  }

  Future<void> _backUpNow() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);
    try {
      await BackupManagerService(widget.database).createManualBackup();
      await _center.refresh(widget.database);
      await _reload();
      _showMessage('A local backup was created successfully.');
    } catch (error) {
      _showMessage('Unable to create a backup: $error');
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _setNotifications(bool enabled) async {
    await _center.setNotificationsEnabled(enabled, widget.database);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final hasUnread = state != null && state.unreadCount > 0;

    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: ArthamColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            key: const Key('alerts-mark-all-read'),
            onPressed: hasUnread ? _markAllRead : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : _buildList(state),
    );
  }

  Widget _buildList(AlertState state) {
    final now = _now;
    final today = <AppAlert>[];
    final earlier = <AppAlert>[];
    for (final alert in state.alerts) {
      final created = alert.createdAt;
      final isToday =
          created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
      (isToday ? today : earlier).add(alert);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _NotificationsSwitch(
          enabled: state.notificationsEnabled,
          onChanged: _setNotifications,
        ),
        const SizedBox(height: 20),
        if (state.alerts.isEmpty) const _EmptyAlerts(),
        if (today.isNotEmpty) ...[
          const _SectionLabel('TODAY'),
          for (final alert in today) _buildCard(alert, now),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SectionLabel('EARLIER'),
          for (final alert in earlier) _buildCard(alert, now),
        ],
        const SizedBox(height: 18),
        const Text(
          'Alerts are created on this phone. Nothing is sent anywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ArthamColors.faint, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCard(AppAlert alert, DateTime now) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AlertCard(
        alert: alert,
        now: now,
        isBackingUp: _isBackingUp,
        onTap: () => _open(alert),
        onBackUp: _backUpNow,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: ArthamColors.lavender,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _NotificationsSwitch extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationsSwitch({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ArthamColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: ArthamColors.lavender,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: ArthamColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Budget overruns, due payments, backup reminders and '
                  'monthly summaries',
                  style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('alerts-notifications-switch'),
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 44,
            color: ArthamColors.faint,
          ),
          SizedBox(height: 12),
          Text(
            'You are all caught up',
            style: TextStyle(
              color: ArthamColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Budget, payment and backup alerts will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ArthamColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AlertStyle {
  final IconData icon;
  final Color color;
  final Color tint;
  final String label;

  const _AlertStyle(this.icon, this.color, this.tint, this.label);

  static _AlertStyle of(AlertKind kind) => switch (kind) {
    AlertKind.budget => const _AlertStyle(
      Icons.warning_amber_rounded,
      ArthamColors.debit,
      ArthamColors.debitTint,
      'Budgets',
    ),
    AlertKind.recurring => const _AlertStyle(
      Icons.event_repeat_rounded,
      ArthamColors.lavender,
      ArthamColors.lavenderTint,
      'Recurring',
    ),
    AlertKind.backup => const _AlertStyle(
      Icons.backup_rounded,
      ArthamColors.mint,
      ArthamColors.mintTint,
      'Backup',
    ),
    AlertKind.summary => const _AlertStyle(
      Icons.bar_chart_rounded,
      ArthamColors.peach,
      ArthamColors.peachTint,
      'Insights',
    ),
  };
}

class _AlertCard extends StatelessWidget {
  final AppAlert alert;
  final DateTime now;
  final bool isBackingUp;
  final VoidCallback onTap;
  final VoidCallback onBackUp;

  const _AlertCard({
    required this.alert,
    required this.now,
    required this.isBackingUp,
    required this.onTap,
    required this.onBackUp,
  });

  static String _ago(DateTime now, DateTime then) {
    final difference = now.difference(then);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    final days = difference.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final style = _AlertStyle.of(alert.kind);
    final unread = !alert.isRead;

    return Semantics(
      label: '${unread ? 'Unread. ' : ''}${alert.title}. ${alert.body}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('alert-${alert.key}'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unread ? style.tint : ArthamColors.glassSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unread
                    ? style.color.withValues(alpha: 0.4)
                    : ArthamColors.line,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                color: unread
                                    ? ArthamColors.text
                                    : ArthamColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: style.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        alert.body,
                        style: const TextStyle(
                          color: ArthamColors.muted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${style.label} · ${_ago(now, alert.createdAt)}',
                        style: const TextStyle(
                          color: ArthamColors.faint,
                          fontSize: 12,
                        ),
                      ),
                      if (alert.kind == AlertKind.backup && unread) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          key: const Key('alerts-back-up-now-button'),
                          onPressed: isBackingUp ? null : onBackUp,
                          style: FilledButton.styleFrom(
                            backgroundColor: ArthamColors.lavender,
                            foregroundColor: ArthamColors.onAccent,
                          ),
                          child: Text(
                            isBackingUp ? 'Backing up…' : 'Back up now',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
