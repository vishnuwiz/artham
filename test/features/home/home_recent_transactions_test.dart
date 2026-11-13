import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/transaction_repository.dart';
import 'package:artham/main.dart';
import 'package:artham/theme/artham_theme.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    initializeAppDatabaseForTesting(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'Home transfer styling matches Activity and Recent transactions See all opens Activity',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        final sourceAccountId = await database
            .into(database.bankAccounts)
            .insert(
              BankAccountsCompanion.insert(
                bankName: 'ICICI Bank',
                accountName: 'Savings',
                accountNumberLast4: const Value('6589'),
                openingBalancePaise: 1000000,
                openingDate: DateTime(2026, 1, 1),
              ),
            );
        final destinationAccountId = await database
            .into(database.bankAccounts)
            .insert(
              BankAccountsCompanion.insert(
                bankName: 'State Bank',
                accountName: 'Savings',
                accountNumberLast4: const Value('1255'),
                openingBalancePaise: 1000000,
                openingDate: DateTime(2026, 1, 1),
              ),
            );

        await TransactionRepository(database).addTransfer(
          fromAccountId: sourceAccountId,
          toAccountId: destinationAccountId,
          amountPaise: 2500,
          transactionDate: DateTime.now(),
          description: 'Own account transfer',
        );
      });

      await tester.pumpWidget(const ArthamApp());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pump();

      final transferAmount = find.text('\u2212\u20B925.00');
      expect(transferAmount, findsOneWidget);
      expect(
        tester.widget<Text>(transferAmount).style?.color,
        ArthamColors.lavender,
      );

      final transferIcon = find.byKey(const ValueKey('home-transfer-icon'));
      expect(transferIcon, findsOneWidget);
      expect(tester.widget<Icon>(transferIcon).color, ArthamColors.lavender);

      final transferIconBackground = find.byKey(
        const ValueKey('home-transfer-icon-background'),
      );
      expect(transferIconBackground, findsOneWidget);
      final iconContainer = tester.widget<Container>(transferIconBackground);
      expect(
        (iconContainer.decoration! as BoxDecoration).color,
        ArthamColors.lavender.withValues(alpha: 0.10),
      );

      final seeAll = find.byKey(
        const ValueKey('home-recent-transactions-see-all'),
      );
      expect(seeAll, findsOneWidget);
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byTooltip('Import bank SMS'), findsOneWidget);
    },
  );
}
