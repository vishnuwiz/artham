import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/setup/first_time_setup_screen.dart';
import 'package:artham/theme/artham_theme.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('prepares starter categories and completes setup',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: FirstTimeSetupScreen(
          database: database,
          onFinish: () async => completed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bring your accounts together.'), findsOneWidget);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Start with useful categories.'), findsOneWidget);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('A CLEARER VIEW OF EVERY RUPEE').hitTestable(),
        findsOneWidget);
    expect(find.text('EXPENSE CATEGORIES'), findsOneWidget);

    final categoriesList =
        find.byKey(const PageStorageKey<String>('setup-categories'));
    final categoriesScrollable = find.descendant(
      of: categoriesList,
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      find.text('INCOME CATEGORIES'),
      250,
      scrollable: categoriesScrollable,
    );
    expect(find.text('INCOME CATEGORIES'), findsOneWidget);

    final categories = await database.select(database.categories).get();
    expect(categories, hasLength(17));
    expect(
      categories.where((category) => category.type == 'expense'),
      hasLength(11),
    );
    expect(
      categories.where((category) => category.type == 'income'),
      hasLength(6),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text("You're all set."), findsOneWidget);
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.text('11 expenses · 6 income'), findsOneWidget);
    await tester.tap(find.text('Go to dashboard'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('Skip completes setup without adding a bank account',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: FirstTimeSetupScreen(
          database: database,
          onFinish: () async => completed = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(completed, isTrue);
    expect(await database.select(database.bankAccounts).get(), isEmpty);
  });
}
