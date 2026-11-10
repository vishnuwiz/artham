import 'package:drift/drift.dart';

import '../app_database.dart';
import '../merchant_intelligence.dart';

/// Persists recognised merchants and links them to transactions.
///
/// The existing Merchants table is reused, so this does not require a
/// database-schema migration. A merchant's default category is set on first
/// recognition and is not overwritten by later transactions.
class MerchantRepository {
  final AppDatabase database;

  MerchantRepository(this.database);

  Future<int?> findOrCreateForDescription({
    required String? description,
    required String transactionType,
    int? fallbackCategoryId,
  }) async {
    // Merchant rules currently describe spending counterparties only.
    if (transactionType != 'expense') return null;

    final match = MerchantIntelligence.recognize(description);
    if (match == null) return null;

    final existing = await (database.select(database.merchants)
          ..where((merchant) => merchant.name.equals(match.name)))
        .getSingleOrNull();

    final catalogCategory = await (database.select(database.categories)
          ..where(
            (category) =>
                category.name.equals(match.categoryName) &
                category.type.equals('expense'),
          ))
        .getSingleOrNull();

    final defaultCategoryId =
        catalogCategory?.id ?? fallbackCategoryId;

    if (existing != null) {
      if (existing.defaultCategoryId == null && defaultCategoryId != null) {
        await (database.update(database.merchants)
              ..where((merchant) => merchant.id.equals(existing.id)))
            .write(
          MerchantsCompanion(
            defaultCategoryId: Value(defaultCategoryId),
          ),
        );
      }
      return existing.id;
    }

    return database.into(database.merchants).insert(
          MerchantsCompanion.insert(
            name: match.name,
            defaultCategoryId: Value(defaultCategoryId),
          ),
        );
  }
}
