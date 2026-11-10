import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/merchant_intelligence.dart';

void main() {
  group('MerchantIntelligence', () {
    test('catalogue supports at least 500 distinct merchants', () {
      expect(MerchantIntelligence.merchantCount, greaterThanOrEqualTo(500));
    });

    test('recognises a merchant from a masked UPI-style description', () {
      final result = MerchantIntelligence.recognize(
        'UPI/DR/123456789/SWIGGY*ORDER123',
      );

      expect(result, isNotNull);
      expect(result!.name, 'Swiggy');
      expect(result.categoryName, 'Food & Dining');
    });

    test('prefers the longest alias for overlapping merchants', () {
      final result = MerchantIntelligence.recognize(
        'SWIGGY INSTAMART ORDER 456',
      );

      expect(result, isNotNull);
      expect(result!.name, 'Swiggy Instamart');
      expect(result.categoryName, 'Groceries');
    });

    test('recognises common Indian merchants across categories', () {
      final cases = {
        'Blinkit order': ('Blinkit', 'Groceries'),
        'AMAZON PAY': ('Amazon', 'Shopping'),
        'Uber trip': ('Uber', 'Transportation'),
        'Netflix subscription': ('Netflix', 'Entertainment'),
        'KSEB bill payment': ('KSEB', 'Bills & Utilities'),
        'Tata 1mg order': ('Tata 1mg', 'Health'),
        'MakeMyTrip booking': ('MakeMyTrip', 'Travel'),
        'Lulu Hypermarket purchase': ('Lulu Hypermarket', 'Groceries'),
        'Decathlon store': ('Decathlon', 'Shopping'),
        'Kochi Metro ticket': ('Kochi Metro', 'Transportation'),
        'Kerala Vision Broadband': ('Kerala Vision Broadband', 'Bills & Utilities'),
        'Amrita Hospital payment': ('Amrita Hospital', 'Health'),
        'IndiGo flight': ('IndiGo', 'Travel'),
        'Third Wave Coffee': ('Third Wave Coffee', 'Food & Dining'),
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
