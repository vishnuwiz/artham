import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/sms_transaction_parser.dart';

void main() {
  test('parses a UPI debit with amount, date, reference and merchant', () {
    final result = SmsTransactionParser().parse(
      'Your A/c XX1234 was debited by Rs. 1,250.50 on 09-11-2026 '
      'to Swiggy. UPI Ref No 123456789012. Available balance Rs. 4,000.00',
    );

    expect(result, isNotNull);
    expect(result!.amountPaise, 125050);
    expect(result.transactionType, 'expense');
    expect(result.transactionDate, DateTime(2026, 11, 9));
    expect(result.referenceNumber, '123456789012');
    expect(result.description, 'Swiggy');
    expect(result.merchantName, 'Swiggy');
    expect(result.suggestedCategory, 'Restaurants');
  });

  test('recognises Instamart as groceries rather than regular Swiggy', () {
    final result = SmsTransactionParser().parse(
      'Rs. 650 debited to SWIGGY INSTAMART on 10-11-2026. UPI Ref 123456789012',
    );

    expect(result, isNotNull);
    expect(result!.description, 'Swiggy Instamart');
    expect(result.merchantName, 'Swiggy Instamart');
    expect(result.suggestedCategory, 'Food & Grocery');
  });

  test('does not mistake a payment provider for the actual payee', () {
    final result = SmsTransactionParser().parse(
      'Rs. 450 debited to Local Book Store using Amazon Pay on 10-11-2026. '
      'UPI Ref No 123456789012',
    );

    expect(result, isNotNull);
    expect(result!.description, 'Local Book Store');
    expect(result.merchantName, isNull);
    expect(result.suggestedCategory, 'Other');
  });

  test('parses an incoming bank credit and named-month date', () {
    final result = SmsTransactionParser().parse(
      'INR 35,000.00 credited to your account on 10 Nov 2026. '
      'UTR 123456789012',
    );

    expect(result, isNotNull);
    expect(result!.amountPaise, 3500000);
    expect(result.transactionType, 'income');
    expect(result.transactionDate, DateTime(2026, 11, 10));
    expect(result.referenceNumber, '123456789012');
    expect(result.suggestedCategory, 'Other');
  });

  test('suggests an income category for a salary credit', () {
    final result = SmsTransactionParser().parse(
      'Salary of INR 82,500 credited to your account on 01/11/2026',
    );

    expect(result, isNotNull);
    expect(result!.transactionType, 'income');
    expect(result.suggestedCategory, 'Income');
    expect(result.amountPaise, 8250000);
  });

  test('parses rupee amounts without decimal places', () {
    final result = SmsTransactionParser().parse(
      'Rs 500 debited for fuel at HP Petrol Pump on 09/11/2026',
    );

    expect(result, isNotNull);
    expect(result!.amountPaise, 50000);
    expect(result.suggestedCategory, 'Transport & Fuel');
  });

  test('returns null for an OTP or non-transaction message', () {
    final result = SmsTransactionParser().parse(
      'Your OTP to authorize this transaction is 481932. Do not share it.',
    );

    expect(result, isNull);
  });

  test('ignores a debit-like alert that includes an OTP/security code', () {
    final result = SmsTransactionParser().parse(
      'Rs. 500 debited from your account. OTP 481932 to authorise the payment.',
    );

    expect(result, isNull);
  });

  test('returns null when debit and credit directions are both present', () {
    final result = SmsTransactionParser().parse(
      'Rs 500 debited and Rs 500 credited to your account.',
    );

    expect(result, isNull);
  });

  test('returns null when a direction has no currency amount', () {
    final result = SmsTransactionParser().parse(
      'Your account has been debited. Please check your statement.',
    );

    expect(result, isNull);
  });

  test('keeps malformed dates unset instead of guessing', () {
    final result = SmsTransactionParser().parse(
      'Rs 500 debited at Shop on 39/19/2026',
    );

    expect(result, isNotNull);
    expect(result!.transactionDate, isNull);
  });
}
