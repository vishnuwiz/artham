import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/category_repository.dart';

void main() {
  test('upgrades a version 2 database to the current version and preserves budgets', () async {
    final month = DateTime(2027, 4, 1);
    final monthStartSeconds = month.millisecondsSinceEpoch ~/ 1000;

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          // The categories table as it existed before schema version 5.
          rawDatabase.execute('''
            CREATE TABLE categories (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              icon_key TEXT NULL,
              color_hex TEXT NULL,
              is_system INTEGER NOT NULL DEFAULT 0
            )
          ''');

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

    // The first Drift query triggers the v2 -> v5 migration.
    final migratedBudget = await database.select(database.budgets).getSingle();

    expect(database.schemaVersion, 5);
    expect(migratedBudget.id, 1);
    expect(migratedBudget.monthStart, month);
    expect(migratedBudget.limitPaise, 250000);
    expect(migratedBudget.rolloverEnabled, isFalse);

    final versionRow = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(versionRow.read<int>('user_version'), 5);
    expect(await database.select(database.budgetTemplates).get(), isEmpty);
  });

  test('upgrades a version 4 database and renames old built-in categories '
      'in place', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE categories (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              icon_key TEXT NULL,
              color_hex TEXT NULL,
              is_system INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDatabase.execute(
            "INSERT INTO categories (id, name, type, is_system) VALUES "
            "(7, 'Food & Dining', 'expense', 1), "
            "(8, 'Salary', 'income', 1), "
            "(9, 'Interest', 'income', 1), "
            "(10, 'Pet care', 'expense', 0)",
          );
          rawDatabase.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(database.close);

    final before = await database.select(database.categories).get();
    expect(before.every((row) => row.seedKey == null), isTrue);
    expect(before.every((row) => !row.isArchived), isTrue);

    await CategoryRepository(database).ensureDefaultCategories();

    Future<Category> byId(int id) => (database.select(database.categories)
          ..where((row) => row.id.equals(id)))
        .getSingle();

    // Same row ids, so transactions and budgets keep their category.
    final restaurants = await byId(7);
    expect(restaurants.name, 'Restaurants');
    expect(restaurants.seedKey, 'expense.restaurants');
    expect(restaurants.iconKey, 'restaurant');

    final income = await byId(8);
    expect(income.name, 'Income');
    expect(income.seedKey, 'income.income');

    // Old built-ins with no new equivalent, and the user's own categories,
    // are left as they are.
    expect((await byId(9)).name, 'Interest');
    expect((await byId(10)).name, 'Pet care');

    final restaurantsRows = await (database.select(database.categories)
          ..where((row) =>
              row.name.equals('Restaurants') & row.type.equals('expense')))
        .get();
    expect(restaurantsRows, hasLength(1));
  });
}
