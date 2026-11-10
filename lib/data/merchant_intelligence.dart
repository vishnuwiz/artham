/// Deterministic, on-device merchant recognition for common Indian payment alerts.
///
/// This is intentionally rule-based: no transaction text is sent to a service,
/// and unrecognised merchants are left untouched for the user to categorise.
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

class _MerchantRule {
  final String name;
  final String categoryName;
  final List<String> aliases;

  const _MerchantRule(this.name, this.categoryName, this.aliases);
}

class _MerchantAlias {
  final String name;
  final String categoryName;
  final String alias;

  const _MerchantAlias(this.name, this.categoryName, this.alias);
}

class MerchantIntelligence {
  MerchantIntelligence._();

  static const List<_MerchantRule> _rules = [
    _MerchantRule('Swiggy Instamart', 'Groceries', [
      'swiggy instamart',
      'instamart',
    ]),
    _MerchantRule('Amazon Prime Video', 'Entertainment', [
      'amazon prime video',
      'prime video',
    ]),
    _MerchantRule('JioMart', 'Groceries', ['jiomart', 'jio mart']),
    _MerchantRule('BigBasket', 'Groceries', ['bigbasket', 'big basket']),
    _MerchantRule('BookMyShow', 'Entertainment', [
      'bookmyshow',
      'book my show',
    ]),
    _MerchantRule('MakeMyTrip', 'Travel', ['makemytrip', 'make my trip']),
    _MerchantRule('Reliance Digital', 'Shopping', ['reliance digital']),
    _MerchantRule('Apollo Pharmacy', 'Health', ['apollo pharmacy']),
    _MerchantRule('Amazon', 'Shopping', ['amazon']),
    _MerchantRule('Flipkart', 'Shopping', ['flipkart']),
    _MerchantRule('Myntra', 'Shopping', ['myntra']),
    _MerchantRule('AJIO', 'Shopping', ['ajio']),
    _MerchantRule('Meesho', 'Shopping', ['meesho']),
    _MerchantRule('Nykaa', 'Shopping', ['nykaa']),
    _MerchantRule('Croma', 'Shopping', ['croma']),
    _MerchantRule('Swiggy', 'Food & Dining', ['swiggy']),
    _MerchantRule('Zomato', 'Food & Dining', ['zomato']),
    _MerchantRule('EatSure', 'Food & Dining', ['eatsure', 'eat sure']),
    _MerchantRule('Dominos', 'Food & Dining', [
      'dominos',
      'domino s',
      'domino pizza',
    ]),
    _MerchantRule('Pizza Hut', 'Food & Dining', ['pizza hut']),
    _MerchantRule('McDonalds', 'Food & Dining', [
      'mcdonalds',
      'mcdonald',
      'mc donalds',
    ]),
    _MerchantRule('KFC', 'Food & Dining', ['kfc']),
    _MerchantRule('Starbucks', 'Food & Dining', ['starbucks']),
    _MerchantRule('Subway', 'Food & Dining', ['subway']),
    _MerchantRule('Burger King', 'Food & Dining', ['burger king']),
    _MerchantRule('Blinkit', 'Groceries', ['blinkit']),
    _MerchantRule('Zepto', 'Groceries', ['zepto']),
    _MerchantRule('DMart', 'Groceries', ['dmart', 'd mart']),
    _MerchantRule('Uber Eats', 'Food & Dining', ['uber eats']),
    _MerchantRule('Uber', 'Transportation', ['uber']),
    _MerchantRule('Ola', 'Transportation', ['ola cabs', 'ola']),
    _MerchantRule('Rapido', 'Transportation', ['rapido']),
    _MerchantRule('Namma Yatri', 'Transportation', ['namma yatri']),
    _MerchantRule('IRCTC', 'Transportation', ['irctc']),
    _MerchantRule('RedBus', 'Transportation', ['redbus', 'red bus']),
    _MerchantRule('Indian Oil', 'Transportation', [
      'indian oil',
      'indianoil',
      'iocl',
    ]),
    _MerchantRule('HPCL', 'Transportation', ['hpcl', 'hp petrol pump']),
    _MerchantRule('BPCL', 'Transportation', ['bpcl', 'bharat petroleum']),
    _MerchantRule('Shell', 'Transportation', ['shell fuel', 'shell petrol']),
    _MerchantRule('Airtel', 'Bills & Utilities', ['airtel']),
    _MerchantRule('Jio', 'Bills & Utilities', ['jio']),
    _MerchantRule('Vi', 'Bills & Utilities', ['vodafone idea', 'vi recharge']),
    _MerchantRule('KSEB', 'Bills & Utilities', [
      'kseb',
      'kerala state electricity board',
    ]),
    _MerchantRule('BESCOM', 'Bills & Utilities', ['bescom']),
    _MerchantRule('Netflix', 'Entertainment', ['netflix']),
    _MerchantRule('Spotify', 'Entertainment', ['spotify']),
    _MerchantRule('YouTube Premium', 'Entertainment', [
      'youtube premium',
    ]),
    _MerchantRule('JioHotstar', 'Entertainment', [
      'jiohotstar',
      'jio hotstar',
      'hotstar',
    ]),
    _MerchantRule('PVR INOX', 'Entertainment', [
      'pvr inox',
      'pvr',
      'inox',
    ]),
    _MerchantRule('Tata 1mg', 'Health', ['tata 1mg', '1mg']),
    _MerchantRule('PharmEasy', 'Health', ['pharmeasy', 'pharm easy']),
    _MerchantRule('Netmeds', 'Health', ['netmeds']),
    _MerchantRule('Goibibo', 'Travel', ['goibibo']),
    _MerchantRule('Cleartrip', 'Travel', ['cleartrip']),
    _MerchantRule('Booking.com', 'Travel', ['booking com']),
    _MerchantRule('Airbnb', 'Travel', ['airbnb']),
    _MerchantRule('Agoda', 'Travel', ['agoda']),
  ];

  static final List<_MerchantAlias> _orderedAliases = [
    for (final rule in _rules)
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
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
