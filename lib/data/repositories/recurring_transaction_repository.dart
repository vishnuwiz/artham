import 'package:drift/drift.dart';

import '../app_database.dart';

/// A recurring schedule together with its account and category.
class RecurringScheduleDetails {
  final RecurringSchedule schedule;
  final BankAccount account;
  final Category category;

  const RecurringScheduleDetails({
    required this.schedule,
    required this.account,
    required this.category,
  });
}

class RecurringTransactionRepository {
  final AppDatabase database;

  RecurringTransactionRepository(this.database);

  /// Creates a recurring income or expense schedule.
  ///
  /// The first occurrence is due on [startDate]. No transaction is created
  /// until the user explicitly confirms that occurrence.
  Future<int> createSchedule({
    required int accountId,
    required int categoryId,
    required int amountPaise,
    required String transactionType,
    required String frequency,
    int interval = 1,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
  }) async {
    _validateSchedule(
      amountPaise: amountPaise,
      transactionType: transactionType,
      frequency: frequency,
      interval: interval,
      startDate: startDate,
      endDate: endDate,
    );

    final account = await (database.select(database.bankAccounts)
          ..where((a) => a.id.equals(accountId) & a.isActive.equals(true)))
        .getSingleOrNull();

    if (account == null) {
      throw ArgumentError('Choose an active bank account.');
    }

    final category = await (database.select(database.categories)
          ..where((c) =>
              c.id.equals(categoryId) & c.type.equals(transactionType)))
        .getSingleOrNull();

    if (category == null) {
      throw ArgumentError(
        'Choose a category that matches the transaction type.',
      );
    }

    final firstDueDate = _dateOnly(startDate);
    final finalDate = endDate == null ? null : _dateOnly(endDate);

    return database.into(database.recurringSchedules).insert(
          RecurringSchedulesCompanion.insert(
            accountId: accountId,
            categoryId: categoryId,
            amountPaise: amountPaise,
            transactionType: transactionType,
            frequency: frequency,
            interval: Value(interval),
            startDate: firstDueDate,
            endDate: Value(finalDate),
            nextDueDate: firstDueDate,
            description: Value(_cleanText(description)),
          ),
        );
  }

  /// Returns all schedules, including paused schedules.
  Future<List<RecurringScheduleDetails>> getSchedules() async {
    final query = database.select(database.recurringSchedules).join([
      innerJoin(
        database.bankAccounts,
        database.bankAccounts.id.equalsExp(
          database.recurringSchedules.accountId,
        ),
      ),
      innerJoin(
        database.categories,
        database.categories.id.equalsExp(
          database.recurringSchedules.categoryId,
        ),
      ),
    ])
      ..orderBy([
        OrderingTerm.asc(database.recurringSchedules.nextDueDate),
        OrderingTerm.desc(database.recurringSchedules.createdAt),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return RecurringScheduleDetails(
        schedule: row.readTable(database.recurringSchedules),
        account: row.readTable(database.bankAccounts),
        category: row.readTable(database.categories),
      );
    }).toList();
  }

  /// Returns active schedules whose next occurrence is due today or earlier,
  /// excluding occurrences that fall after the schedule's end date.
  Future<List<RecurringScheduleDetails>> getDueSchedules({
    DateTime? asOf,
  }) async {
    final today = _dateOnly(asOf ?? DateTime.now());

    final query = database.select(database.recurringSchedules).join([
      innerJoin(
        database.bankAccounts,
        database.bankAccounts.id.equalsExp(
          database.recurringSchedules.accountId,
        ),
      ),
      innerJoin(
        database.categories,
        database.categories.id.equalsExp(
          database.recurringSchedules.categoryId,
        ),
      ),
    ])
      ..where(
        database.recurringSchedules.isActive.equals(true) &
            database.recurringSchedules.nextDueDate
                .isSmallerOrEqualValue(today),
      )
      ..orderBy([
        OrderingTerm.asc(database.recurringSchedules.nextDueDate),
      ]);

    final rows = await query.get();

    return rows
        .map((row) {
          return RecurringScheduleDetails(
            schedule: row.readTable(database.recurringSchedules),
            account: row.readTable(database.bankAccounts),
            category: row.readTable(database.categories),
          );
        })
        .where((item) {
          final endDate = item.schedule.endDate;

          return endDate == null ||
              !_dateOnly(endDate).isBefore(
                _dateOnly(item.schedule.nextDueDate),
              );
        })
        .toList();
  }

  /// Pauses or resumes a schedule without changing its next due date.
  Future<bool> setScheduleActive({
    required int scheduleId,
    required bool isActive,
  }) async {
    final changed = await (database.update(database.recurringSchedules)
          ..where((s) => s.id.equals(scheduleId)))
        .write(RecurringSchedulesCompanion(
      isActive: Value(isActive),
    ));

    return changed > 0;
  }

  /// Deletes a schedule. Transactions already created from it are retained.
  Future<bool> deleteSchedule(int scheduleId) async {
    final deleted = await (database.delete(database.recurringSchedules)
          ..where((s) => s.id.equals(scheduleId)))
        .go();

    return deleted > 0;
  }

  /// Confirms and records the schedule's next due occurrence.
  ///
  /// The operation is atomic. A deterministic internal reference number
  /// makes confirming the same occurrence twice safe, including after an
  /// app restart. Existing manual transfers and transactions are untouched.
  ///
  /// Returns true when a transaction was created, false when that occurrence
  /// had already been recorded or is not currently confirmable.
  Future<bool> confirmNextOccurrence(int scheduleId) async {
    return database.transaction(() async {
      final schedule = await (database.select(database.recurringSchedules)
            ..where((s) => s.id.equals(scheduleId)))
          .getSingleOrNull();

      if (schedule == null || !schedule.isActive) {
        return false;
      }

      final dueDate = _dateOnly(schedule.nextDueDate);
      final today = _dateOnly(DateTime.now());

      if (dueDate.isAfter(today)) {
        return false;
      }

      final endDate =
          schedule.endDate == null ? null : _dateOnly(schedule.endDate!);

      if (endDate != null && dueDate.isAfter(endDate)) {
        await (database.update(database.recurringSchedules)
              ..where((s) => s.id.equals(scheduleId)))
            .write(const RecurringSchedulesCompanion(
          isActive: Value(false),
        ));
        return false;
      }

      final occurrenceKey = _occurrenceKey(schedule.id, dueDate);

      final alreadyRecorded = await (database.select(database.moneyTransactions)
            ..where((t) => t.referenceNumber.equals(occurrenceKey)))
          .getSingleOrNull();

      if (alreadyRecorded != null) {
        // Repair the schedule pointer if a previous attempt recorded the
        // transaction but did not advance the schedule.
        await _advanceSchedule(schedule, dueDate, endDate);
        return false;
      }

      final account = await (database.select(database.bankAccounts)
            ..where((a) => a.id.equals(schedule.accountId)))
          .getSingleOrNull();

      if (account == null || !account.isActive) {
        throw StateError('The bank account for this schedule is unavailable.');
      }

      await database.into(database.moneyTransactions).insert(
            MoneyTransactionsCompanion.insert(
              accountId: schedule.accountId,
              categoryId: Value(schedule.categoryId),
              amountPaise: schedule.amountPaise,
              transactionType: schedule.transactionType,
              transactionDate: dueDate,
              description: Value(
                _cleanText(schedule.description) ??
                    (schedule.transactionType == 'income'
                        ? 'Recurring income'
                        : 'Recurring expense'),
              ),
              referenceNumber: Value(occurrenceKey),
              source: const Value('recurring'),
            ),
          );

      await _advanceSchedule(schedule, dueDate, endDate);
      return true;
    });
  }

  Future<void> _advanceSchedule(
    RecurringSchedule schedule,
    DateTime dueDate,
    DateTime? endDate,
  ) async {
    final nextDate = _nextOccurrence(
      dueDate,
      schedule.frequency,
      schedule.interval,
    );

    final shouldRemainActive = endDate == null || !nextDate.isAfter(endDate);

    await (database.update(database.recurringSchedules)
          ..where((s) => s.id.equals(schedule.id)))
        .write(RecurringSchedulesCompanion(
      nextDueDate: Value(nextDate),
      isActive: Value(shouldRemainActive),
    ));
  }

  static void _validateSchedule({
    required int amountPaise,
    required String transactionType,
    required String frequency,
    required int interval,
    required DateTime startDate,
    required DateTime? endDate,
  }) {
    if (amountPaise <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (transactionType != 'income' && transactionType != 'expense') {
      throw ArgumentError('Recurring schedules support income or expense only.');
    }
    if (!const {'daily', 'weekly', 'monthly', 'yearly'}.contains(frequency)) {
      throw ArgumentError('Choose a valid recurring frequency.');
    }
    if (interval < 1 || interval > 999) {
      throw ArgumentError('Repeat interval must be between 1 and 999.');
    }
    if (endDate != null &&
        _dateOnly(endDate).isBefore(_dateOnly(startDate))) {
      throw ArgumentError('End date cannot be before the start date.');
    }
  }

  static DateTime _nextOccurrence(
    DateTime current,
    String frequency,
    int interval,
  ) {
    switch (frequency) {
      case 'daily':
        return current.add(Duration(days: interval));
      case 'weekly':
        return current.add(Duration(days: 7 * interval));
      case 'monthly':
        final targetMonth = DateTime(
          current.year,
          current.month + interval,
          1,
        );
        final lastDay = DateTime(
          targetMonth.year,
          targetMonth.month + 1,
          0,
        ).day;
        final day = current.day > lastDay ? lastDay : current.day;
        return DateTime(targetMonth.year, targetMonth.month, day);
      case 'yearly':
        final targetYear = current.year + interval;
        final lastDay = DateTime(targetYear, current.month + 1, 0).day;
        final day = current.day > lastDay ? lastDay : current.day;
        return DateTime(targetYear, current.month, day);
      default:
        throw ArgumentError('Unsupported frequency: $frequency');
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _occurrenceKey(int scheduleId, DateTime dueDate) {
    final date =
        '${dueDate.year.toString().padLeft(4, '0')}-'
        '${dueDate.month.toString().padLeft(2, '0')}-'
        '${dueDate.day.toString().padLeft(2, '0')}';
    return 'ARTHAM-RECURRING-$scheduleId-$date';
  }

  static String? _cleanText(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
