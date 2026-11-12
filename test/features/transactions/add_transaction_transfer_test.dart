import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/transactions/add_transaction_screen.dart';

void main() {
  testWidgets('Add Transaction offers a Transfer option', (tester) async {
    // Tall viewport so the whole ListView is built, including the save button.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late AppDatabase database;

    await tester.runAsync(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      for (final entry in const [
        ('HDFC Bank', '1234'),
        ('ICICI Bank', '5678'),
      ]) {
        await database
            .into(database.bankAccounts)
            .insert(
              BankAccountsCompanion.insert(
                bankName: entry.$1,
                accountName: 'Savings',
                accountNumberLast4: Value(entry.$2),
                openingBalancePaise: 100000,
                openingDate: DateTime(2026, 1, 1),
              ),
            );
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: AddTransactionScreen(database: database),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Save Transaction'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Transaction Date'), findsOneWidget);
    expect(find.text('Transaction Time'), findsOneWidget);

    await tester.tap(find.text('Transfer'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Confirm Transfer'), findsOneWidget);
    expect(find.text('From account'), findsOneWidget);
    expect(find.text('To account'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
    expect(find.text('Save Transaction'), findsNothing);

    await tester.runAsync(() => database.close());
  });
}
