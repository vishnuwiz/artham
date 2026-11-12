/// Built-in categories that ship with Artham, and the mapping used to upgrade
/// the categories created by earlier versions of the app.
///
/// This file has no Flutter dependency. Icons are referenced by key; the keys
/// are resolved to Material icons in `lib/theme/category_icons.dart`.
library;

class DefaultCategory {
  /// Stable identifier stored in `categories.seed_key`.
  final String seedKey;
  final String name;

  /// `expense` or `income`.
  final String type;
  final String iconKey;
  final String colorHex;

  const DefaultCategory({
    required this.seedKey,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorHex,
  });
}

/// Pastel colours offered for categories. The first is the default.
const List<String> categoryColorPalette = [
  '#B9A5F5', // lavender
  '#8FE3C4', // mint
  '#FFD3A0', // peach
  '#8CBEFF', // sky
  '#FF8F8F', // rose
  '#F5A5D6', // pink
  '#F5E08C', // lemon
  '#7FD8E0', // teal
];

const String _lavender = '#B9A5F5';
const String _mint = '#8FE3C4';
const String _peach = '#FFD3A0';
const String _sky = '#8CBEFF';
const String _rose = '#FF8F8F';
const String _pink = '#F5A5D6';
const String _lemon = '#F5E08C';
const String _teal = '#7FD8E0';

DefaultCategory _expense(String key, String name, String icon, String color) =>
    DefaultCategory(
      seedKey: 'expense.$key',
      name: name,
      type: 'expense',
      iconKey: icon,
      colorHex: color,
    );

DefaultCategory _income(String key, String name, String icon, String color) =>
    DefaultCategory(
      seedKey: 'income.$key',
      name: name,
      type: 'income',
      iconKey: icon,
      colorHex: color,
    );

/// The default category list. Categories that money can flow both ways
/// through (Investment, Business, Gift, Self Transfer) exist once as an
/// expense category and once as an income category.
final List<DefaultCategory> defaultCategoryCatalog = [
  // Expense
  _expense('investment', 'Investment', 'trending_up', _mint),
  _expense('personal', 'Personal', 'person', _lavender),
  _expense('work', 'Work', 'work', _sky),
  _expense('business', 'Business', 'sell', _teal),
  _expense('restaurants', 'Restaurants', 'restaurant', _peach),
  _expense('housing', 'Housing', 'home', _lavender),
  _expense('electricity', 'Electricity', 'lightbulb', _lemon),
  _expense('transport_fuel', 'Transport & Fuel', 'directions_car', _sky),
  _expense('food_grocery', 'Food & Grocery', 'local_grocery_store', _mint),
  _expense('medical', 'Medical', 'local_hospital', _rose),
  _expense('travel', 'Travel', 'flight', _teal),
  _expense('fitness', 'Fitness', 'fitness_center', _mint),
  _expense('insurance', 'Insurance', 'health_and_safety', _sky),
  _expense('entertainment', 'Entertainment', 'movie', _pink),
  _expense('internet_telecom', 'Internet & Telecom', 'wifi', _sky),
  _expense('gift', 'Gift', 'card_giftcard', _pink),
  _expense('taxes', 'Taxes', 'receipt_long', _peach),
  _expense('utility', 'Utility', 'water_drop', _teal),
  _expense('shopping', 'Shopping', 'shopping_bag', _pink),
  _expense('card_repayment', 'Card Repayment', 'credit_card', _lavender),
  _expense('atm', 'ATM', 'local_atm', _mint),
  _expense('bank_charges', 'Bank Charges', 'account_balance', _rose),
  _expense('self_transfer', 'Self Transfer', 'sync_alt', _lavender),
  _expense('loan', 'Loan', 'request_quote', _peach),
  _expense('education', 'Education', 'school', _lemon),
  _expense('other', 'Other', 'category', _lavender),

  // Income
  _income('income', 'Income', 'payments', _mint),
  _income('reimbursement', 'Reimbursement', 'currency_exchange', _teal),
  _income('investment', 'Investment', 'trending_up', _mint),
  _income('business', 'Business', 'sell', _teal),
  _income('gift', 'Gift', 'card_giftcard', _pink),
  _income('self_transfer', 'Self Transfer', 'sync_alt', _lavender),
  _income('other', 'Other', 'category', _lavender),
];

/// Built-in categories from earlier versions, keyed by `type|name`, mapped to
/// the seed key of the category they become. The existing row is renamed in
/// place so transactions, budgets and schedules keep their category.
///
/// Legacy categories not listed here (for example Interest) are kept as they
/// are and become ordinary, editable categories.
const Map<String, String> legacyCategorySeedKeys = {
  'expense|Food & Dining': 'expense.restaurants',
  'expense|Groceries': 'expense.food_grocery',
  'expense|Transportation': 'expense.transport_fuel',
  'expense|Bills & Utilities': 'expense.utility',
  'expense|Health': 'expense.medical',
  'expense|Rent': 'expense.housing',
  'expense|Shopping': 'expense.shopping',
  'expense|Entertainment': 'expense.entertainment',
  'expense|Education': 'expense.education',
  'expense|Travel': 'expense.travel',
  'expense|Other Expense': 'expense.other',
  'income|Salary': 'income.income',
  'income|Business Income': 'income.business',
  'income|Investment Returns': 'income.investment',
  'income|Gift': 'income.gift',
  'income|Other Income': 'income.other',
};

/// Name of the built-in fallback category for a transaction type.
const String otherCategoryName = 'Other';
