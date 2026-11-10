import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/transactions/bank_statement_import_screen.dart';

void main() {
  testWidgets('shows statement import guidance and destination account', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.into(database.bankAccounts).insert(
      BankAccountsCompanion.insert(
        bankName: 'Federal Bank',
        accountName: 'Primary',
        accountNumberLast4: const Value('1255'),
        openingBalancePaise: 1000000,
        openingDate: DateTime(2026, 1, 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BankStatementImportScreen(database: database),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import bank statement'), findsOneWidget);
    expect(find.text('Import a bank statement'), findsOneWidget);
    expect(find.text('Choose statement file'), findsOneWidget);
    expect(find.text('Destination account'), findsOneWidget);
    expect(find.text('Federal Bank · •••• 1255'), findsOneWidget);
    expect(find.textContaining('CSV, XLSX and legacy XLS'), findsOneWidget);
  });
}
