import 'package:drift/drift.dart';

import '../app_database.dart';
import '../category_catalog.dart';

/// Thrown when a category can't be saved, with a message for the user.
class CategoryValidationException implements Exception {
  final String message;

  const CategoryValidationException(this.message);

  @override
  String toString() => message;
}

/// Result of [CategoryRepository.deleteCategory].
enum CategoryDeleteResult {
  /// The row was removed because nothing referred to it.
  deleted,

  /// The row was hidden because transactions, budgets, schedules or
  /// merchants still refer to it, or because it is a built-in category.
  archived,
}

/// Creates, edits and removes categories, and keeps the built-in list seeded.
class CategoryRepository {
  final AppDatabase database;

  CategoryRepository(this.database);

  static const int maxNameLength = 32;

  /// Seeds the built-in categories and upgrades those created by earlier
  /// versions of the app. Safe to call repeatedly.
  ///
  /// Each default is identified by its seed key, so one the user renamed or
  /// hid is left alone rather than re-created.
  Future<void> ensureDefaultCategories() async {
    await database.transaction(() async {
      final rows = await database.select(database.categories).get();
      final bySeedKey = <String, Category>{
        for (final row in rows)
          if (row.seedKey != null) row.seedKey!: row,
      };

      // 1. Upgrade built-in categories from earlier versions in place.
      for (final row in rows) {
        if (!row.isSystem || row.seedKey != null) continue;
        final seedKey = legacyCategorySeedKeys['${row.type}|${row.name}'];
        if (seedKey == null || bySeedKey.containsKey(seedKey)) continue;
        final target = _defaultFor(seedKey);
        if (target == null) continue;

        final nameTaken = rows.any(
          (other) =>
              other.id != row.id &&
              other.type == target.type &&
              _sameName(other.name, target.name),
        );

        await (database.update(
          database.categories,
        )..where((category) => category.id.equals(row.id))).write(
          CategoriesCompanion(
            name: nameTaken ? const Value.absent() : Value(target.name),
            seedKey: Value(seedKey),
            iconKey: Value(row.iconKey ?? target.iconKey),
            colorHex: Value(row.colorHex ?? target.colorHex),
          ),
        );
        bySeedKey[seedKey] = row;
      }

      // 2. Insert any defaults that don't exist yet.
      final current = await database.select(database.categories).get();
      for (final item in defaultCategoryCatalog) {
        if (bySeedKey.containsKey(item.seedKey)) continue;

        // A category with the same name and type (for example one the user
        // created before this version) is adopted rather than duplicated.
        final sameName = current.where(
          (row) =>
              row.seedKey == null &&
              row.type == item.type &&
              _sameName(row.name, item.name),
        );
        if (sameName.isNotEmpty) {
          final row = sameName.first;
          await (database.update(
            database.categories,
          )..where((category) => category.id.equals(row.id))).write(
            CategoriesCompanion(
              seedKey: Value(item.seedKey),
              iconKey: Value(row.iconKey ?? item.iconKey),
              colorHex: Value(row.colorHex ?? item.colorHex),
            ),
          );
          continue;
        }

        await database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                name: item.name,
                type: item.type,
                iconKey: Value(item.iconKey),
                colorHex: Value(item.colorHex),
                isSystem: const Value(true),
                seedKey: Value(item.seedKey),
              ),
            );
      }
    });
  }

  /// Categories of one type, sorted by name. Hidden ones are left out unless
  /// [includeArchived] is true.
  Future<List<Category>> getCategories(
    String type, {
    bool includeArchived = false,
  }) {
    final query = database.select(database.categories)
      ..where((category) {
        final ofType = category.type.equals(type);
        return includeArchived
            ? ofType
            : ofType & category.isArchived.equals(false);
      })
      ..orderBy([(category) => OrderingTerm.asc(category.name)]);
    return query.get();
  }

  Future<int> createCategory({
    required String name,
    required String type,
    required String iconKey,
    required String colorHex,
  }) async {
    _checkType(type);
    final cleanName = _validateName(name);

    return database.transaction(() async {
      final existing = await _findByName(cleanName, type);
      if (existing != null) {
        if (!existing.isArchived) {
          throw CategoryValidationException(
            '“${existing.name}” already exists.',
          );
        }
        // Creating a category with a hidden category's name brings it back,
        // so its history rejoins it.
        await (database.update(
          database.categories,
        )..where((category) => category.id.equals(existing.id))).write(
          CategoriesCompanion(
            name: Value(cleanName),
            iconKey: Value(iconKey),
            colorHex: Value(colorHex),
            isArchived: const Value(false),
          ),
        );
        return existing.id;
      }

      return database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: cleanName,
              type: type,
              iconKey: Value(iconKey),
              colorHex: Value(colorHex),
            ),
          );
    });
  }

  /// Renames a category or changes its icon or colour. The type can't change,
  /// because existing transactions depend on it.
  Future<void> updateCategory({
    required int id,
    required String name,
    required String iconKey,
    required String colorHex,
  }) async {
    final cleanName = _validateName(name);

    await database.transaction(() async {
      final category = await _getById(id);
      final clash = await _findByName(cleanName, category.type);
      if (clash != null && clash.id != id) {
        throw CategoryValidationException(
          clash.isArchived
              ? '“${clash.name}” is a hidden category. Restore it instead.'
              : '“${clash.name}” already exists.',
        );
      }

      await (database.update(
        database.categories,
      )..where((item) => item.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(cleanName),
          iconKey: Value(iconKey),
          colorHex: Value(colorHex),
        ),
      );
    });
  }

  /// Number of transactions, budgets, budget templates, recurring schedules
  /// and merchants that refer to the category.
  Future<int> countUsage(int id) async {
    Future<int> count(String table, String column) async {
      final row = await database
          .customSelect(
            'SELECT COUNT(*) AS c FROM $table WHERE $column = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();
      return row.read<int>('c');
    }

    return await count('money_transactions', 'category_id') +
        await count('budgets', 'category_id') +
        await count('budget_templates', 'category_id') +
        await count('recurring_schedules', 'category_id') +
        await count('merchants', 'default_category_id');
  }

  /// Number of transactions in the category.
  Future<int> countTransactions(int id) async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS c FROM money_transactions WHERE category_id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Removes a category. One that is still referred to, or a built-in one, is
  /// hidden instead so history keeps its label and seeding doesn't re-add it.
  ///
  /// The last visible category of a type can't be removed, because adding a
  /// transaction needs at least one.
  Future<CategoryDeleteResult> deleteCategory(int id) async {
    return database.transaction(() async {
      final category = await _getById(id);
      final visible = await getCategories(category.type);
      if (!category.isArchived &&
          visible.where((item) => item.id != id).isEmpty) {
        throw const CategoryValidationException(
          'Keep at least one category of each type.',
        );
      }

      final inUse = await countUsage(id) > 0;
      if (inUse || category.seedKey != null) {
        await (database.update(database.categories)
              ..where((item) => item.id.equals(id)))
            .write(const CategoriesCompanion(isArchived: Value(true)));
        return CategoryDeleteResult.archived;
      }

      await (database.delete(
        database.categories,
      )..where((item) => item.id.equals(id))).go();
      return CategoryDeleteResult.deleted;
    });
  }

  /// Makes a hidden category available in pickers again.
  Future<void> restoreCategory(int id) async {
    final category = await _getById(id);
    final clash = (await getCategories(category.type))
        .where((item) => item.id != id && _sameName(item.name, category.name));
    if (clash.isNotEmpty) {
      throw CategoryValidationException(
        'Another category is already called “${category.name}”. '
        'Rename it first.',
      );
    }
    await (database.update(database.categories)
          ..where((item) => item.id.equals(id)))
        .write(const CategoriesCompanion(isArchived: Value(false)));
  }

  Future<Category> _getById(int id) async {
    final category = await (database.select(
      database.categories,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    if (category == null) {
      throw const CategoryValidationException('Category not found.');
    }
    return category;
  }

  Future<Category?> _findByName(String name, String type) async {
    final rows = await (database.select(
      database.categories,
    )..where((category) => category.type.equals(type))).get();
    final matches = rows.where((row) => _sameName(row.name, name)).toList()
      // Prefer a visible match over a hidden one.
      ..sort((a, b) => (a.isArchived ? 1 : 0) - (b.isArchived ? 1 : 0));
    return matches.isEmpty ? null : matches.first;
  }

  static String _validateName(String name) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      throw const CategoryValidationException('Enter a category name.');
    }
    if (clean.length > maxNameLength) {
      throw const CategoryValidationException(
        'Use $maxNameLength characters or fewer.',
      );
    }
    return clean;
  }

  static void _checkType(String type) {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError.value(type, 'type', 'Must be expense or income');
    }
  }

  static bool _sameName(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static DefaultCategory? _defaultFor(String seedKey) {
    for (final item in defaultCategoryCatalog) {
      if (item.seedKey == seedKey) return item;
    }
    return null;
  }
}
