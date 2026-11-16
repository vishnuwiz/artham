import '../repositories/budget_repository.dart';
import '../repositories/recurring_transaction_repository.dart';
import 'app_alert.dart';

/// A notification the operating system should show at [when], even if the
/// app is closed.
class ScheduledNote {
  final int id;
  final String alertKey;
  final DateTime when;
  final String title;
  final String body;

  const ScheduledNote({
    required this.id,
    required this.alertKey,
    required this.when,
    required this.title,
    required this.body,
  });
}

class MonthTotals {
  final int incomePaise;
  final int expensePaise;

  const MonthTotals({required this.incomePaise, required this.expensePaise});

  bool get hasActivity => incomePaise > 0 || expensePaise > 0;
}

/// Pure functions that turn budgets, recurring schedules, backup age and
/// monthly totals into alerts and a notification schedule.
abstract final class AlertEngine {
  static const int backupStaleDays = 7;
  static const int _recurringWindowDays = 60;
  static const int _maxScheduled = 100;

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String monthName(int month) => _months[(month - 1) % 12];

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String dayKey(DateTime date) =>
      '${monthKey(date)}-${date.day.toString().padLeft(2, '0')}';

  /// Formats paise as rupees with Indian digit grouping, e.g. ₹1,14,200.50.
  static String formatRupees(int paise) {
    final negative = paise < 0;
    final absolute = paise.abs();
    final whole = (absolute ~/ 100).toString();
    final fraction = absolute % 100;

    var grouped = whole;
    if (whole.length > 3) {
      final lastThree = whole.substring(whole.length - 3);
      var rest = whole.substring(0, whole.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      grouped = '${parts.join(',')},$lastThree';
    }

    final decimals = fraction == 0
        ? ''
        : '.${fraction.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}₹$grouped$decimals';
  }

  // ---------------------------------------------------------------- budgets

  static List<AppAlert> budgetAlerts({
    required DateTime now,
    required MonthlyBudgetSummary? overall,
    required List<CategoryBudgetSummary> categories,
  }) {
    final alerts = <AppAlert>[];
    final month = monthKey(now);
    final monthLabel = monthName(now.month);

    if (overall != null &&
        overall.availableBudgetPaise > 0 &&
        overall.expensesPaise > overall.availableBudgetPaise) {
      final percent =
          (overall.expensesPaise * 100 / overall.availableBudgetPaise).round();
      alerts.add(
        AppAlert(
          key: 'budget-overall-$month',
          kind: AlertKind.budget,
          title: 'Monthly budget exceeded',
          body:
              'You have used $percent% of your $monthLabel budget '
              '(${formatRupees(overall.expensesPaise)} of '
              '${formatRupees(overall.availableBudgetPaise)}).',
          createdAt: now,
        ),
      );
    }

    for (final item in categories) {
      if (item.availableBudgetPaise <= 0) continue;
      if (item.expensesPaise <= item.availableBudgetPaise) continue;
      final percent =
          (item.expensesPaise * 100 / item.availableBudgetPaise).round();
      alerts.add(
        AppAlert(
          key: 'budget-category-${item.category.id}-$month',
          kind: AlertKind.budget,
          title: '${item.category.name} budget exceeded',
          body:
              'You have used $percent% of your $monthLabel '
              '${item.category.name} budget '
              '(${formatRupees(item.expensesPaise)} of '
              '${formatRupees(item.availableBudgetPaise)}).',
          createdAt: now,
        ),
      );
    }
    return alerts;
  }

  // -------------------------------------------------------------- recurring

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Whole calendar days from today until [due] (negative when overdue).
  static int _daysUntil(DateTime now, DateTime due) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final dueDay = DateTime.utc(due.year, due.month, due.day);
    return dueDay.difference(today).inDays;
  }

  static bool _isLive(RecurringScheduleDetails details) {
    final schedule = details.schedule;
    if (!schedule.isActive) return false;
    final end = schedule.endDate;
    return end == null ||
        !_dateOnly(end).isBefore(_dateOnly(schedule.nextDueDate));
  }

  static String _scheduleName(RecurringScheduleDetails details) {
    final description = details.schedule.description?.trim();
    if (description != null && description.isNotEmpty) return description;
    return details.category.name;
  }

  static String _recurringKey(RecurringScheduleDetails details) {
    return 'recurring-${details.schedule.id}-'
        '${dayKey(details.schedule.nextDueDate)}';
  }

  static (String title, String body) _recurringText(
    RecurringScheduleDetails details,
    int daysUntilDue,
  ) {
    final name = _scheduleName(details);
    final amount = formatRupees(details.schedule.amountPaise);
    final bank = details.account.bankName;
    final isIncome = details.schedule.transactionType == 'income';

    final when = daysUntilDue < 0
        ? 'is overdue'
        : daysUntilDue == 0
        ? 'is due today'
        : 'is due tomorrow';
    final body = isIncome
        ? '$amount is expected in your $bank account. '
              'Confirm it in Recurring once it arrives.'
        : '$amount will be paid from your $bank account. '
              'Make sure there is enough balance, then confirm it in Recurring.';
    return ('$name $when', body);
  }

  static List<AppAlert> recurringAlerts({
    required DateTime now,
    required List<RecurringScheduleDetails> schedules,
  }) {
    final alerts = <AppAlert>[];
    for (final details in schedules) {
      if (!_isLive(details)) continue;
      final days = _daysUntil(now, details.schedule.nextDueDate);
      if (days > 1) continue;
      final text = _recurringText(details, days);
      alerts.add(
        AppAlert(
          key: _recurringKey(details),
          kind: AlertKind.recurring,
          title: text.$1,
          body: text.$2,
          createdAt: now,
        ),
      );
    }
    return alerts;
  }

  // ----------------------------------------------------------------- backup

  static String backupKey(DateTime? lastBackupAt) => lastBackupAt == null
      ? 'backup-none'
      : 'backup-${lastBackupAt.toUtc().millisecondsSinceEpoch}';

  static (String title, String body) _backupText(int? daysSinceBackup) {
    if (daysSinceBackup == null) {
      return (
        'Back up your data',
        'You have not made a backup yet. Create one to keep your data safe.',
      );
    }
    return (
      'Time for a backup',
      'Your last backup was $daysSinceBackup days ago. '
          'Create a new one to keep your data safe.',
    );
  }

  static AppAlert? backupAlert({
    required DateTime now,
    required DateTime? lastBackupAt,
  }) {
    int? days;
    if (lastBackupAt != null) {
      days = now.difference(lastBackupAt).inDays;
      if (days < backupStaleDays) return null;
    }
    final text = _backupText(days);
    return AppAlert(
      key: backupKey(lastBackupAt),
      kind: AlertKind.backup,
      title: text.$1,
      body: text.$2,
      createdAt: now,
    );
  }

  // ---------------------------------------------------------------- summary

  static String summaryKey(DateTime month) => 'summary-${monthKey(month)}';

  /// The summary of the month before [now]'s month.
  static AppAlert? monthlySummaryAlert({
    required DateTime now,
    required MonthTotals previousMonth,
  }) {
    if (!previousMonth.hasActivity) return null;
    final month = DateTime(now.year, now.month - 1, 1);

    final income = previousMonth.incomePaise;
    final expense = previousMonth.expensePaise;
    final buffer = StringBuffer(
      'You earned ${formatRupees(income)} and spent ${formatRupees(expense)}.',
    );
    if (income > 0 && income >= expense) {
      final kept = ((income - expense) * 100 / income).round();
      buffer.write(' You kept $kept% of your income.');
    } else if (expense > income) {
      buffer.write(
        ' You spent ${formatRupees(expense - income)} more than you earned.',
      );
    }

    return AppAlert(
      key: summaryKey(month),
      kind: AlertKind.summary,
      title: '${monthName(month.month)} summary is ready',
      body: buffer.toString(),
      createdAt: now,
    );
  }

  // -------------------------------------------------- notification schedule

  /// Future notifications the OS should deliver while the app is closed.
  static List<ScheduledNote> plan({
    required DateTime now,
    required List<RecurringScheduleDetails> schedules,
    required DateTime? lastBackupAt,
    required bool thisMonthHasActivity,
  }) {
    final notes = <ScheduledNote>[];
    final horizon = now.add(const Duration(days: _recurringWindowDays));

    for (final details in schedules) {
      if (!_isLive(details)) continue;
      final due = _dateOnly(details.schedule.nextDueDate);
      if (due.isAfter(horizon)) continue;
      final key = _recurringKey(details);

      final dayBefore = DateTime(due.year, due.month, due.day - 1, 9);
      final dueMorning = DateTime(due.year, due.month, due.day, 9);
      final tomorrow = _recurringText(details, 1);
      final today = _recurringText(details, 0);

      if (dayBefore.isAfter(now)) {
        notes.add(
          ScheduledNote(
            id: 100000 + details.schedule.id * 2,
            alertKey: key,
            when: dayBefore,
            title: tomorrow.$1,
            body: tomorrow.$2,
          ),
        );
      }
      if (dueMorning.isAfter(now)) {
        notes.add(
          ScheduledNote(
            id: 100000 + details.schedule.id * 2 + 1,
            alertKey: key,
            when: dueMorning,
            title: today.$1,
            body: today.$2,
          ),
        );
      }
    }

    // Backup reminder: a week after the last backup (tomorrow if none yet).
    final base = lastBackupAt?.toLocal() ?? now;
    final backupAt = DateTime(
      base.year,
      base.month,
      base.day + (lastBackupAt == null ? 1 : backupStaleDays),
      10,
    );
    if (backupAt.isAfter(now)) {
      final text = _backupText(lastBackupAt == null ? null : backupStaleDays);
      notes.add(
        ScheduledNote(
          id: 2000001,
          alertKey: backupKey(lastBackupAt),
          when: backupAt,
          title: text.$1,
          body: text.$2,
        ),
      );
    }

    // Monthly summary: the morning of the 1st, if this month had activity.
    if (thisMonthHasActivity) {
      final first = DateTime(now.year, now.month + 1, 1, 9);
      notes.add(
        ScheduledNote(
          id: 2000002,
          alertKey: summaryKey(DateTime(now.year, now.month, 1)),
          when: first,
          title: '${monthName(now.month)} summary is ready',
          body: 'See how your month went in Alerts.',
        ),
      );
    }

    notes.sort((a, b) => a.when.compareTo(b.when));
    return notes.length > _maxScheduled
        ? notes.sublist(0, _maxScheduled)
        : notes;
  }
}
