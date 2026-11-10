import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/merchant_repository.dart';

void main() {
  late AppDatabase database;
  late MerchantRepository repository;
  late int foodCategoryId;
  late int shoppingCategoryId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = MerchantRepository(database);

    foodCategoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Food & Dining',
            type: 'expense',
            isSystem: const Value(true),
          ),
        );
    shoppingCategoryId = await database.into(database.categories).insert(
          CategoriesCompanion.insert(
            name: 'Shopping',
            type: 'expense',
            isSystem: const Value(true),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a merchant with its catalogue category', () async {
    final id = await repository.findOrCreateForDescription(
      description: 'SWIGGY*ORDER123',
      transactionType: 'expense',
      fallbackCategoryId: shoppingCategoryId,
    );

    expect(id, isNotNull);
    final merchant = await (database.select(database.merchants)
          ..where((row) => row.id.equals(id!)))
        .getSingle();

    expect(merchant.name, 'Swiggy');
    // The catalogue category takes precedence over the fallback category.
    expect(merchant.defaultCategoryId, foodCategoryId);
  });

  test('reuses an existing merchant without overwriting its default category',
      () async {
    final firstId = await repository.findOrCreateForDescription(
      description: 'Swiggy',
      transactionType: 'expense',
      fallbackCategoryId: foodCategoryId,
    );
    final secondId = await repository.findOrCreateForDescription(
      description: 'Payment to SWIGGY',
      transactionType: 'expense',
      fallbackCategoryId: shoppingCategoryId,
    );

    expect(secondId, firstId);
    expect(await database.select(database.merchants).get(), hasLength(1));

    final merchant = (await database.select(database.merchants).get()).single;
    expect(merchant.defaultCategoryId, foodCategoryId);
  });

  test('does not classify income descriptions as merchants', () async {
    final id = await repository.findOrCreateForDescription(
      description: 'Salary from Amazon',
      transactionType: 'income',
      fallbackCategoryId: shoppingCategoryId,
    );

    expect(id, isNull);
    expect(await database.select(database.merchants).get(), isEmpty);
  });

  test('leaves unknown merchants unlinked', () async {
    final id = await repository.findOrCreateForDescription(
      description: 'Payment to Local Book Store',
      transactionType: 'expense',
      fallbackCategoryId: shoppingCategoryId,
    );

    expect(id, isNull);
    expect(await database.select(database.merchants).get(), isEmpty);
  });

  test('uses the supplied category when the catalogue category is absent',
      () async {
    await database.delete(database.categories).go();

    final id = await repository.findOrCreateForDescription(
      description: 'Swiggy',
      transactionType: 'expense',
      fallbackCategoryId: shoppingCategoryId,
    );

    final merchant = await (database.select(database.merchants)
          ..where((row) => row.id.equals(id!)))
        .getSingle();

    expect(merchant.defaultCategoryId, shoppingCategoryId);
  });
}
