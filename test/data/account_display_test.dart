import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/app_database.dart';

void main() {
  group('bank account display labels', () {
    test('shows bank name with the masked last four digits', () {
      expect(
        bankAccountDisplayLabel('Federal Bank', '1255'),
        'Federal Bank · •••• 1255',
      );
    });

    test('uses a placeholder when last four digits are missing', () {
      expect(accountNumberLastFourLabel(null), '•••• ----');
      expect(
        bankAccountDisplayLabel('ICICI Bank', ''),
        'ICICI Bank · •••• ----',
      );
    });

    test('keeps the legacy database field populated without a nickname', () {
      expect(legacyAccountNameForStorage('6983'), 'Account 6983');
      expect(legacyAccountNameForStorage(null), 'Account');
    });
  });
}
