import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/category_catalog.dart';
import 'package:artham/theme/category_icons.dart';

void main() {
  test('every built-in category uses an icon from the icon set', () {
    for (final item in defaultCategoryCatalog) {
      expect(
        categoryIcons.containsKey(item.iconKey),
        isTrue,
        reason: '${item.name} uses unknown icon "${item.iconKey}"',
      );
    }
  });

  test('built-in seed keys are unique', () {
    final keys = defaultCategoryCatalog.map((item) => item.seedKey).toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('old built-in categories map to existing defaults', () {
    final keys = defaultCategoryCatalog.map((item) => item.seedKey).toSet();
    for (final target in legacyCategorySeedKeys.values) {
      expect(keys, contains(target));
    }
  });

  test('unknown icon keys and colours fall back safely', () {
    expect(categoryIconFor('not-an-icon'), categoryIcons['category']);
    expect(categoryColorFor('oops').toARGB32(), isNonZero);
    expect(categoryColorFor('#8FE3C4').toARGB32(), 0xFF8FE3C4);
  });
}
