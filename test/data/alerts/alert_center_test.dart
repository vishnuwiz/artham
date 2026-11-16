import 'dart:io';

import 'package:artham/data/alerts/alert_center.dart';
import 'package:artham/data/alerts/alert_engine.dart';
import 'package:artham/data/alerts/alert_store.dart';
import 'package:artham/data/alerts/app_alert.dart';
import 'package:artham/data/alerts/notification_service.dart';
import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/budget_repository.dart';
import 'package:artham/data/repositories/recurring_transaction_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotifications extends NotificationService {
  final List<String> shown = [];
  List<ScheduledNote> lastPlan = const [];
  int cancelAllCalls = 0;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add(title);
  }

  @override
  Future<void> replaceSchedule(List<ScheduledNote> notes) async {
    lastPlan = notes;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }
}

void main() {
  late AppDatabase database;
  late Directory documents;
  late _FakeNotifications notifications;
  late AlertCenter center;
  late int accountId;
  late int categoryId;

  final now = DateTime(2026, 11, 14, 12);

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('artham-alerts-test-');
    notifications = _FakeNotifications();
    center = AlertCenter(
      notifications: notifications,
      documentsDirectoryProvider: () async => documents,
      clock: () => now,
    );

    accountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'Test Bank',
            accountName: 'Test Account',
            openingBalancePaise: 0,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    categoryId = await database
        .into(database.categories)
        .insert(CategoriesCompanion.insert(name: 'Food', type: 'expense'));
  });

  tearDown(() async {
    await database.close();
    await documents.delete(recursive: true);
  });

  test('raises a backup reminder once and notifies once', () async {
    await center.refresh(database);
    await center.refresh(database);

    final state = await center.load();
    expect(state.alerts, hasLength(1));
    expect(state.alerts.single.key, 'backup-none');
    expect(notifications.shown, ['Back up your data']);
    expect(center.unreadCount.value, 1);
    expect(notifications.lastPlan.any((note) => note.id == 2000001), isTrue);
  });

  test('raises and announces a budget overrun', () async {
    await BudgetRepository(
      database,
    ).saveMonthlyBudget(month: now, limitPaise: 100000);
    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            categoryId: Value(categoryId),
            amountPaise: 150000,
            transactionType: 'expense',
            transactionDate: DateTime(2026, 11, 5),
          ),
        );

    await center.refresh(database);

    final state = await center.load();
    final alert = state.alerts.singleWhere(
      (alert) => alert.key == 'budget-overall-2026-11',
    );
    expect(alert.kind, AlertKind.budget);
    expect(alert.title, 'Monthly budget exceeded');
    expect(alert.body, contains('150%'));
    expect(notifications.shown, contains('Monthly budget exceeded'));
    // This month had spending, so next month's summary is scheduled too.
    expect(notifications.lastPlan.any((note) => note.id == 2000002), isTrue);
  });

  test('warns the day before a recurring payment is due', () async {
    final scheduleId = await RecurringTransactionRepository(database)
        .createSchedule(
          accountId: accountId,
          categoryId: categoryId,
          amountPaise: 64900,
          transactionType: 'expense',
          frequency: 'monthly',
          startDate: DateTime(2026, 11, 15),
          description: 'Netflix',
        );

    await center.refresh(database);

    final state = await center.load();
    final alert = state.alerts.singleWhere(
      (alert) => alert.kind == AlertKind.recurring,
    );
    expect(alert.key, 'recurring-$scheduleId-2026-11-15');
    expect(alert.title, 'Netflix is due tomorrow');
    expect(notifications.shown, contains('Netflix is due tomorrow'));
    expect(
      notifications.lastPlan.any(
        (note) =>
            note.alertKey == alert.key && note.when == DateTime(2026, 11, 15, 9),
      ),
      isTrue,
    );
  });

  test('does not announce twice what the OS already announced', () async {
    final scheduleId = await RecurringTransactionRepository(database)
        .createSchedule(
          accountId: accountId,
          categoryId: categoryId,
          amountPaise: 64900,
          transactionType: 'expense',
          frequency: 'monthly',
          startDate: DateTime(2026, 11, 15),
          description: 'Netflix',
        );
    await center.store.save(
      AlertState(scheduledKeys: {'recurring-$scheduleId-2026-11-15'}),
    );

    await center.refresh(database);

    final state = await center.load();
    expect(
      state.alerts.any((alert) => alert.kind == AlertKind.recurring),
      isTrue,
    );
    expect(notifications.shown, isNot(contains('Netflix is due tomorrow')));
  });

  test('marking alerts read clears the badge', () async {
    await center.refresh(database);
    expect(center.unreadCount.value, 1);

    await center.markAllRead();

    final state = await center.load();
    expect(state.alerts.every((alert) => alert.isRead), isTrue);
    expect(center.unreadCount.value, 0);
  });

  test('shows no notifications while they are switched off', () async {
    await center.setNotificationsEnabled(false, database);

    final state = await center.load();
    expect(state.notificationsEnabled, isFalse);
    expect(state.alerts, hasLength(1));
    expect(notifications.shown, isEmpty);
    expect(notifications.cancelAllCalls, greaterThan(0));
  });

  test('a damaged alerts file falls back to an empty state', () async {
    final file = File('${documents.path}/Artham/alerts.json');
    await file.parent.create(recursive: true);
    await file.writeAsString('{ not json');

    final state = await center.load();

    expect(state.alerts, isEmpty);
    expect(state.notificationsEnabled, isTrue);
  });
}
