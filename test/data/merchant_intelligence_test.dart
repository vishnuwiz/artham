import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/merchant_intelligence.dart';
import 'package:artham/data/merchant_catalog_data.dart';

void main() {
  group('MerchantIntelligence', () {
    test('catalogue supports at least 500 distinct merchants', () {
      expect(MerchantIntelligence.merchantCount, greaterThanOrEqualTo(500));
    });

    test(
      'recognises every canonical merchant alias with its mapped category',
      () {
        var testedAliases = 0;

        for (final merchant in merchantCatalogData) {
          for (final alias in merchant.aliases) {
            final result = MerchantIntelligence.recognize(
              'UPI PAYMENT TO $alias',
            );

            expect(result, isNotNull, reason: 'Alias: $alias');
            expect(result!.name, merchant.name, reason: 'Alias: $alias');
            expect(
              result.categoryName,
              merchant.categoryName,
              reason: 'Alias: $alias',
            );
            testedAliases++;
          }
        }

        expect(testedAliases, greaterThanOrEqualTo(1000));
      },
    );

    test('recognises a merchant from a masked UPI-style description', () {
      final result = MerchantIntelligence.recognize(
        'UPI/DR/123456789/SWIGGY*ORDER123',
      );

      expect(result, isNotNull);
      expect(result!.name, 'Swiggy');
      expect(result.categoryName, 'Restaurants');
    });

    test('prefers the longest alias for overlapping merchants', () {
      final result = MerchantIntelligence.recognize(
        'SWIGGY INSTAMART ORDER 456',
      );

      expect(result, isNotNull);
      expect(result!.name, 'Swiggy Instamart');
      expect(result.categoryName, 'Food & Grocery');
    });

    test('recognises common Indian merchants across categories', () {
      final cases = {
        'Blinkit order': ('Blinkit', 'Food & Grocery'),
        'AMAZON PAY': ('Amazon', 'Shopping'),
        'Uber trip': ('Uber', 'Transport & Fuel'),
        'Netflix subscription': ('Netflix', 'Entertainment'),
        'KSEB bill payment': ('KSEB', 'Electricity'),
        'Tata 1mg order': ('Tata 1mg', 'Medical'),
        'MakeMyTrip booking': ('MakeMyTrip', 'Travel'),
        'Lulu Hypermarket purchase': ('Lulu Hypermarket', 'Food & Grocery'),
        'Decathlon store': ('Decathlon', 'Shopping'),
        'Kochi Metro ticket': ('Kochi Metro', 'Transport & Fuel'),
        'Kerala Vision Broadband': (
          'Kerala Vision Broadband',
          'Internet & Telecom',
        ),
        'Amrita Hospital payment': ('Amrita Hospital', 'Medical'),
        'IndiGo flight': ('IndiGo', 'Travel'),
        'Third Wave Coffee': ('Third Wave Coffee', 'Restaurants'),
        'ManoramaMAX subscription': ('ManoramaMAX', 'Entertainment'),
      };

      for (final entry in cases.entries) {
        final result = MerchantIntelligence.recognize(entry.key);
        expect(result, isNotNull, reason: entry.key);
        expect(result!.name, entry.value.$1, reason: entry.key);
        expect(result.categoryName, entry.value.$2, reason: entry.key);
      }
    });

    test('uses token boundaries and does not match partial words', () {
      expect(MerchantIntelligence.recognize('Solar equipment payment'), isNull);
      expect(MerchantIntelligence.recognize('Net amount transferred'), isNull);
      expect(MerchantIntelligence.recognize('My Netflixx account'), isNull);
    });

    test('leaves unknown merchants unclassified', () {
      expect(
        MerchantIntelligence.recognize('UPI payment to Local Book Store'),
        isNull,
      );
      expect(MerchantIntelligence.recognize(null), isNull);
      expect(MerchantIntelligence.recognize('   '), isNull);
    });
  });
}
