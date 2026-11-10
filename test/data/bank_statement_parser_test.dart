import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/bank_statement_parser.dart';

void main() {
  group('BankStatementParser', () {
    test('detects a header row after a report preamble', () {
      final rows = [
        ['Federal Bank Statement', '', '', ''],
        ['Account number', 'XXXX1255', '', ''],
        ['Date', 'Narration', 'Debit', 'Credit', 'Ref No'],
        ['10/11/2026', 'Swiggy', '250.00', '', 'UPI001'],
      ];

      expect(BankStatementParser.detectHeaderRow(rows), 2);
    });

    test('maps common debit and credit statement headings', () {
      final mapping = BankStatementParser.detectMapping([
        'Transaction Date',
        'Particulars',
        'Withdrawal (Dr)',
        'Deposit (Cr)',
        'UTR Number',
      ]);

      expect(mapping.dateColumn, 0);
      expect(mapping.descriptionColumn, 1);
      expect(mapping.debitColumn, 2);
      expect(mapping.creditColumn, 3);
      expect(mapping.referenceColumn, 4);
      expect(mapping.amountColumn, isNull);
    });

    test('parses debit and credit rows as separate expense and income', () {
      final headers = ['Date', 'Narration', 'Debit', 'Credit', 'Reference'];
      final mapping = BankStatementParser.detectMapping(headers);
      final result = BankStatementParser.parse(
        headers: headers,
        mapping: mapping,
        rows: [
          ['10/11/2026', 'Swiggy', '1,234.50', '', 'UPI-101'],
          ['11/11/2026', 'Salary', '', '50,000.00', 'SAL-102'],
        ],
      );

      expect(result.configurationError, isNull);
      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].transactionType, 'expense');
      expect(result.transactions[0].amountPaise, 123450);
      expect(result.transactions[1].transactionType, 'income');
      expect(result.transactions[1].amountPaise, 5000000);
      expect(result.transactions[0].referenceNumber, 'UPI-101');
    });

    test('parses Indian day-first, named month, and Excel serial dates', () {
      expect(BankStatementParser.parseDate('10/11/2026'), DateTime(2026, 11, 10));
      expect(BankStatementParser.parseDate('10-Nov-2026'), DateTime(2026, 11, 10));
      expect(BankStatementParser.parseDate('46335'), DateTime(2026, 11, 9));
    });

    test('uses signed amount or explicit Dr/Cr type safely', () {
      final headers = ['Date', 'Description', 'Amount', 'Type'];
      final mapping = BankStatementParser.detectMapping(headers);
      final result = BankStatementParser.parse(
        headers: headers,
        mapping: mapping,
        rows: [
          ['10/11/2026', 'Rent', '-5000.00', ''],
          ['10/11/2026', 'Salary', '50000', 'Cr'],
          ['10/11/2026', 'Unknown direction', '120.00', ''],
        ],
      );

      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].transactionType, 'expense');
      expect(result.transactions[1].transactionType, 'income');
      expect(result.skippedRows, 1);
    });

    test('skips invalid dates, blank narration, and ambiguous debit/credit rows', () {
      final headers = ['Date', 'Description', 'Debit', 'Credit'];
      final mapping = BankStatementParser.detectMapping(headers);
      final result = BankStatementParser.parse(
        headers: headers,
        mapping: mapping,
        rows: [
          ['bad date', 'Coffee', '100', ''],
          ['10/11/2026', '', '100', ''],
          ['10/11/2026', 'Ambiguous', '100', '200'],
          ['10/11/2026', 'Valid', '25', ''],
        ],
      );

      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.description, 'Valid');
      expect(result.skippedRows, 3);
    });

    test('requires explicit mapping and does not guess positive amount direction', () {
      final noMapping = BankStatementParser.parse(
        headers: const ['Date', 'Description'],
        rows: const [],
        mapping: const StatementColumnMapping(
          dateColumn: 0,
          descriptionColumn: 1,
        ),
      );
      expect(noMapping.configurationError, contains('either Debit/Credit'));

      final mapping = BankStatementParser.detectMapping([
        'Date',
        'Description',
        'Amount',
      ]);
      final result = BankStatementParser.parse(
        headers: ['Date', 'Description', 'Amount'],
        rows: [
          ['10/11/2026', 'Payment', '100.00'],
        ],
        mapping: mapping,
      );
      expect(result.transactions, isEmpty);
      expect(result.skippedRows, 1);
    });
  });
}
