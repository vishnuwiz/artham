import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';

void main() {
  test('upgrades a version 2 budget and defaults rollover to off', () async {
    final month = DateTime(2027, 4, 1);
    final monthStartSeconds = month.millisecondsSinceEpoch ~/ 1000;

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          // This is the budgets table as it existed in schema version 2,
          // before the rollover_enabled column was introduced.
          rawDatabase.execute('''
            CREATE TABLE budgets (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              category_id INTEGER NULL REFERENCES categories (id),
              month_start INTEGER NOT NULL,
              limit_paise INTEGER NOT NULL,
              created_at INTEGER NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          rawDatabase.execute(
            '''
              INSERT INTO budgets (
                id,
                category_id,
                month_start,
                limit_paise,
                created_at
              ) VALUES (1, NULL, ?, 250000, ?)
            ''',
            [monthStartSeconds, monthStartSeconds],
          );

          // Tell Drift that this database was last opened by schema v2.
          rawDatabase.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(database.close);

    // The first Drift query triggers the v2 -> v3 migration.
    final migratedBudget = await database.select(database.budgets).getSingle();

    expect(database.schemaVersion, 3);
    expect(migratedBudget.id, 1);
    expect(migratedBudget.monthStart, month);
    expect(migratedBudget.limitPaise, 250000);
    expect(migratedBudget.rolloverEnabled, isFalse);

    final versionRow =
        await database.customSelect('PRAGMA user_version').getSingle();
    expect(versionRow.read<int>('user_version'), 3);
  });
}
