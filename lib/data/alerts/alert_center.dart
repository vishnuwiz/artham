import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;

import '../app_database.dart';
import '../backup_manager.dart';
import '../repositories/budget_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import 'alert_engine.dart';
import 'alert_store.dart';
import 'app_alert.dart';
import 'notification_service.dart';

/// Keeps the alert list up to date and decides which notifications to show.
///
/// Call [refresh] when the app starts, resumes, or the user moves between
/// tabs (that is when a new budget overrun can have been caused).
class AlertCenter {
  AlertCenter({
    AlertStore? store,
    NotificationService? notifications,
    Future<Directory> Function()? documentsDirectoryProvider,
    DateTime Function()? clock,
  }) : _documentsDirectoryProvider = documentsDirectoryProvider,
       store = store ?? AlertStore(documentsDirectoryProvider: documentsDirectoryProvider),
       notifications = notifications ?? NotificationService.instance,
       _clock = clock ?? DateTime.now;

  static final AlertCenter instance = AlertCenter();

  static const Duration _keepAlertsFor = Duration(days: 60);

  final AlertStore store;
  final NotificationService notifications;
  final Future<Directory> Function()? _documentsDirectoryProvider;
  final DateTime Function() _clock;

  /// Number of unread alerts, for the badge on the Home bell.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<void> _tail = Future<void>.value();
  Future<void>? _queuedRefresh;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<AlertState> load() => _serial(() async {
    final state = await store.load();
    unreadCount.value = state.unreadCount;
    return state;
  });

  /// Runs all alert checks. Calls made while a refresh is already waiting
  /// share that refresh instead of piling up.
  Future<void> refresh(AppDatabase database) {
    final waiting = _queuedRefresh;
    if (waiting != null) return waiting;
    late Future<void> run;
    run = _serial(() async {
      // From here on a new call may queue another refresh.
      if (identical(_queuedRefresh, run)) _queuedRefresh = null;
      await _refresh(database);
    }).catchError((Object error) {
      debugPrint('Artham alerts refresh failed: $error');
    });
    _queuedRefresh = run;
    return run;
  }

  /// Asks for notification permission once, then runs a first refresh.
  Future<void> start(AppDatabase database) async {
    try {
      final state = await load();
      if (state.notificationsEnabled && !state.permissionAsked) {
        await notifications.requestPermission();
        await _serial(() async {
          final latest = await store.load();
          await store.save(latest.copyWith(permissionAsked: true));
        });
      }
    } catch (error) {
      debugPrint('Artham alerts start failed: $error');
    }
    await refresh(database);
  }

  Future<void> markRead(String key) => _serial(() async {
    final state = await store.load();
    final alerts = [
      for (final alert in state.alerts)
        alert.key == key ? alert.copyWith(isRead: true) : alert,
    ];
    await _save(state.copyWith(alerts: alerts));
  });

  Future<void> markAllRead() => _serial(() async {
    final state = await store.load();
    final alerts = [
      for (final alert in state.alerts) alert.copyWith(isRead: true),
    ];
    await _save(state.copyWith(alerts: alerts));
  });

  Future<void> setNotificationsEnabled(
    bool enabled,
    AppDatabase database,
  ) async {
    if (enabled) await notifications.requestPermission();
    await _serial(() async {
      final state = await store.load();
      await store.save(
        state.copyWith(notificationsEnabled: enabled, permissionAsked: true),
      );
    });
    if (!enabled) await notifications.cancelAll();
    await refresh(database);
  }

  Future<void> _save(AlertState state) async {
    await store.save(state);
    unreadCount.value = state.unreadCount;
  }

  Future<void> _refresh(AppDatabase database) async {
    final now = _clock();
    final state = await store.load();

    final budgets = BudgetRepository(database);
    final overall = await budgets.getMonthlyBudgetSummary(now);
    final categories = await budgets.getCategoryBudgetSummaries(now);
    final schedules = await RecurringTransactionRepository(
      database,
    ).getSchedules();
    final lastBackup = await _lastBackupAt(database);
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousTotals = await _monthTotals(database, previousMonth);
    final thisMonthTotals = await _monthTotals(database, now);

    final candidates = <AppAlert>[
      ...AlertEngine.budgetAlerts(
        now: now,
        overall: overall,
        categories: categories,
      ),
      ...AlertEngine.recurringAlerts(now: now, schedules: schedules),
      ?AlertEngine.backupAlert(now: now, lastBackupAt: lastBackup),
      ?AlertEngine.monthlySummaryAlert(now: now, previousMonth: previousTotals),
    ];

    // Merge: existing alerts keep their read state and creation time.
    final merged = {for (final alert in state.alerts) alert.key: alert};
    final created = <AppAlert>[];
    for (final candidate in candidates) {
      final existing = merged[candidate.key];
      if (existing == null) {
        merged[candidate.key] = candidate;
        created.add(candidate);
      } else {
        merged[candidate.key] = existing.copyWith(
          title: candidate.title,
          body: candidate.body,
        );
      }
    }

    // A backup alert stops mattering once a newer backup exists.
    final currentBackupKey = AlertEngine.backupAlert(
      now: now,
      lastBackupAt: lastBackup,
    )?.key;
    for (final entry in merged.entries.toList()) {
      final alert = entry.value;
      if (alert.kind == AlertKind.backup &&
          alert.key != currentBackupKey &&
          !alert.isRead) {
        merged[entry.key] = alert.copyWith(isRead: true);
      }
    }

    final cutoff = now.subtract(_keepAlertsFor);
    final alerts = merged.values
        .where((alert) => alert.createdAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final plan = AlertEngine.plan(
      now: now,
      schedules: schedules,
      lastBackupAt: lastBackup,
      thisMonthHasActivity: thisMonthTotals.hasActivity,
    );

    if (state.notificationsEnabled) {
      for (final alert in created) {
        // The OS already announced alerts we had scheduled for. Budget
        // overruns are never scheduled, so they are always announced here.
        final announcedByOs =
            alert.kind != AlertKind.budget &&
            state.scheduledKeys.contains(alert.key);
        if (announcedByOs) continue;
        await notifications.show(
          id: _notificationId(alert.key),
          title: alert.title,
          body: alert.body,
        );
      }
      await notifications.replaceSchedule(plan);
    } else {
      await notifications.cancelAll();
    }

    await _save(
      state.copyWith(
        alerts: alerts,
        scheduledKeys: state.notificationsEnabled
            ? {for (final note in plan) note.alertKey}
            : const <String>{},
      ),
    );
  }

  Future<DateTime?> _lastBackupAt(AppDatabase database) async {
    final manager = BackupManagerService(
      database,
      documentsDirectoryProvider: _documentsDirectoryProvider,
    );
    final history = await manager.listBackupHistory();
    for (final entry in history) {
      if (entry.kind != BackupKind.restoreSafety) return entry.createdAt;
    }
    return null;
  }

  Future<MonthTotals> _monthTotals(AppDatabase database, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows =
        await (database.select(database.moneyTransactions)..where(
              (row) =>
                  row.transactionDate.isBiggerOrEqualValue(start) &
                  row.transactionDate.isSmallerThanValue(end),
            ))
            .get();

    var income = 0;
    var expense = 0;
    for (final row in rows) {
      if (row.transactionType == 'income') income += row.amountPaise;
      if (row.transactionType == 'expense') expense += row.amountPaise;
    }
    return MonthTotals(incomePaise: income, expensePaise: expense);
  }

  /// A stable, positive 30-bit id derived from the alert key.
  static int _notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x3fffffff;
    }
    return hash + 3000000;
  }
}
