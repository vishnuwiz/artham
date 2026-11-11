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

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Start with useful categories.'), findsOneWidget);
    expect(find.text('EXPENSE CATEGORIES'), findsOneWidget);
    expect(find.text('INCOME CATEGORIES'), findsOneWidget);

    final categories = await database.select(database.categories).get();
    expect(categories, hasLength(17));

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text("You're all set."), findsOneWidget);
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
