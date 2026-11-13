import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/transactions/import_sms_screen.dart';
import 'package:artham/theme/artham_theme.dart';

void main() {
  late AppDatabase database;
  late int hdfcAccountId;
  late int iciciAccountId;

  Future<void> createAccounts() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    hdfcAccountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'HDFC Bank',
            accountName: 'Savings',
            accountNumberLast4: const Value('1234'),
            openingBalancePaise: 500000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
    iciciAccountId = await database
        .into(database.bankAccounts)
        .insert(
          BankAccountsCompanion.insert(
            bankName: 'ICICI Bank',
            accountName: 'Savings',
            accountNumberLast4: const Value('5678'),
            openingBalancePaise: 500000,
            openingDate: DateTime(2026, 1, 1),
          ),
        );
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: ImportSmsScreen(database: database),
      ),
    );
  }

  Future<void> parseMessage(WidgetTester tester, String message) async {
    await tester.enterText(find.byKey(const Key('sms-message-field')), message);
    await tester.tap(find.byKey(const Key('parse-sms-button')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setupDatabase(WidgetTester tester) async {
    await tester.runAsync(createAccounts);
    addTearDown(() async {
      await tester.runAsync(() => database.close());
    });
  }

  testWidgets('selects the saved bank account whose last four digits match', (
    tester,
  ) async {
    await setupDatabase(tester);
    await openScreen(tester);
    await parseMessage(
      tester,
      'Your A/c XX5678 was debited by Rs. 450 on 10-11-2026 to Swiggy. '
      'UPI Ref No 123456789012',
    );

    final accountField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const Key('sms-account-dropdown')),
    );
    expect(accountField.initialValue, iciciAccountId);
    expect(accountField.initialValue, isNot(hdfcAccountId));
    expect(
      find.textContaining('Matched the saved account ending in 5678'),
      findsOneWidget,
    );
  });

  testWidgets('does not default to the first account when no suffix matches', (
    tester,
  ) async {
    await setupDatabase(tester);
    await openScreen(tester);
    await parseMessage(
      tester,
      'Your A/c XX9999 was debited by Rs. 450 on 10-11-2026 to Swiggy.',
    );

    final accountField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const Key('sms-account-dropdown')),
    );
    expect(accountField.initialValue, isNull);
    expect(
      find.textContaining('No saved account ends in 9999'),
      findsOneWidget,
    );
  });
}
