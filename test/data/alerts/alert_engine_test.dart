import 'package:artham/data/alerts/alert_engine.dart';
import 'package:artham/data/alerts/app_alert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRupees', () {
    test('uses Indian digit grouping and drops empty decimals', () {
      expect(AlertEngine.formatRupees(0), '₹0');
      expect(AlertEngine.formatRupees(150), '₹1.50');
      expect(AlertEngine.formatRupees(111420), '₹1,114.20');
      expect(AlertEngine.formatRupees(28007200), '₹2,80,072');
    });
  });

  group('backupAlert', () {
    final now = DateTime(2026, 11, 14, 12);

    test('asks for a first backup when none exists', () {
      final alert = AlertEngine.backupAlert(now: now, lastBackupAt: null);

      expect(alert, isNotNull);
      expect(alert!.key, 'backup-none');
      expect(alert.kind, AlertKind.backup);
      expect(alert.title, 'Back up your data');
    });

    test('stays quiet while the last backup is recent', () {
      final alert = AlertEngine.backupAlert(
        now: now,
        lastBackupAt: now.subtract(const Duration(days: 3)),
      );

      expect(alert, isNull);
    });

    test('reminds once the last backup is a week old', () {
      final last = now.subtract(const Duration(days: 10));
      final alert = AlertEngine.backupAlert(now: now, lastBackupAt: last);

      expect(alert, isNotNull);
      expect(alert!.key, AlertEngine.backupKey(last));
      expect(alert.title, 'Time for a backup');
      expect(alert.body, contains('10 days ago'));
    });
  });

  group('monthlySummaryAlert', () {
    final now = DateTime(2026, 11, 14, 12);

    test('summarises the previous month', () {
      final alert = AlertEngine.monthlySummaryAlert(
        now: now,
        previousMonth: const MonthTotals(
          incomePaise: 5000000,
          expensePaise: 742800,
        ),
      );

      expect(alert, isNotNull);
      expect(alert!.key, 'summary-2026-10');
      expect(alert.title, 'October summary is ready');
      expect(
        alert.body,
        'You earned ₹50,000 and spent ₹7,428. You kept 85% of your income.',
      );
    });

    test('says so when spending was higher than income', () {
      final alert = AlertEngine.monthlySummaryAlert(
        now: now,
        previousMonth: const MonthTotals(
          incomePaise: 1000000,
          expensePaise: 1500000,
        ),
      );

      expect(alert!.body, contains('You spent ₹5,000 more than you earned.'));
    });

    test('is skipped when the month had no activity', () {
      final alert = AlertEngine.monthlySummaryAlert(
        now: now,
        previousMonth: const MonthTotals(incomePaise: 0, expensePaise: 0),
      );

      expect(alert, isNull);
    });

    test('wraps around the year boundary', () {
      final alert = AlertEngine.monthlySummaryAlert(
        now: DateTime(2027, 1, 3),
        previousMonth: const MonthTotals(incomePaise: 100, expensePaise: 50),
      );

      expect(alert!.key, 'summary-2026-12');
      expect(alert.title, 'December summary is ready');
    });
  });

  group('plan', () {
    final now = DateTime(2026, 11, 14, 12);

    test('schedules a first-backup nudge and next month\'s summary', () {
      final notes = AlertEngine.plan(
        now: now,
        schedules: const [],
        lastBackupAt: null,
        thisMonthHasActivity: true,
      );

      final backup = notes.singleWhere((note) => note.id == 2000001);
      final summary = notes.singleWhere((note) => note.id == 2000002);
      expect(backup.when, DateTime(2026, 11, 15, 10));
      expect(backup.alertKey, 'backup-none');
      expect(summary.when, DateTime(2026, 12, 1, 9));
      expect(summary.alertKey, 'summary-2026-11');
    });

    test('schedules the backup reminder a week after the last backup', () {
      final last = DateTime(2026, 11, 10, 8);
      final notes = AlertEngine.plan(
        now: now,
        schedules: const [],
        lastBackupAt: last,
        thisMonthHasActivity: false,
      );

      final backup = notes.singleWhere((note) => note.id == 2000001);
      expect(backup.when, DateTime(2026, 11, 17, 10));
      expect(backup.alertKey, AlertEngine.backupKey(last));
      expect(notes.any((note) => note.id == 2000002), isFalse);
    });

    test('never schedules a moment that has already passed', () {
      final notes = AlertEngine.plan(
        now: now,
        schedules: const [],
        lastBackupAt: DateTime(2026, 10, 1),
        thisMonthHasActivity: false,
      );

      expect(notes.any((note) => note.id == 2000001), isFalse);
    });
  });
}
