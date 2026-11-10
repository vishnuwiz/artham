import 'merchant_catalog_data.dart';

/// Deterministic, on-device merchant recognition for Indian payment alerts.
///
/// The merchant records and aliases are generated from
/// tool/data/merchant_catalog.json. The catalogue is intentionally offline:
/// no transaction text is sent to a service, and unknown payees remain
/// unclassified instead of being guessed.
class MerchantRecognition {
  final String name;
  final String categoryName;
  final String matchedAlias;

  const MerchantRecognition({
    required this.name,
    required this.categoryName,
    required this.matchedAlias,
  });
}

class _MerchantAlias {
  final String name;
  final String categoryName;
  final String alias;

  const _MerchantAlias(this.name, this.categoryName, this.alias);
}

class MerchantIntelligence {
  MerchantIntelligence._();

  /// Number of distinct canonical merchant names in the offline catalogue.
  static int get merchantCount => merchantCatalogData.length;

  static final List<_MerchantAlias> _orderedAliases = [
    for (final rule in merchantCatalogData)
      for (final alias in rule.aliases)
        _MerchantAlias(rule.name, rule.categoryName, _normalize(alias)),
  ]..sort((a, b) => b.alias.length.compareTo(a.alias.length));

  /// Finds a known merchant using whole-token matching.
  ///
  /// Longer aliases are checked first so "Swiggy Instamart" is not
  /// misclassified as the regular Swiggy food-delivery service.
  static MerchantRecognition? recognize(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = ' ${_normalize(value)} ';
    if (normalized.trim().isEmpty) return null;

    for (final alias in _orderedAliases) {
      if (normalized.contains(' ${alias.alias} ')) {
        return MerchantRecognition(
          name: alias.name,
          categoryName: alias.categoryName,
          matchedAlias: alias.alias,
        );
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\\s+'), ' ');
  }
}
