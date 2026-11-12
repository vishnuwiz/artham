import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/category_catalog.dart';
import 'package:artham/data/first_time_setup_store.dart';
import 'package:artham/data/repositories/account_repository.dart';
import 'package:artham/features/setup/first_time_setup_gate.dart';
import 'package:artham/features/setup/first_time_setup_screen.dart';

class _MemorySetupStore implements FirstTimeSetupStore {
  bool completed = false;

  @override
  Future<bool> hasCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
  }
}

void main() {
  late AppDatabase database;
  late _MemorySetupStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = _MemorySetupStore();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows setup for a new installation without accounts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstTimeSetupGate(
          database: database,
          store: store,
          child: const Text('Dashboard'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FirstTimeSetupScreen), findsOneWidget);
    expect(find.text('Set up Artham'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('existing active accounts bypass setup and seed categories',
      (tester) async {
    await AccountRepository(database).addAccount(
      bankName: 'Federal Bank',
      accountName: 'Account 1234',
      accountNumberLast4: '1234',
      openingBalancePaise: 125000,
      openingDate: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstTimeSetupGate(
          database: database,
          store: store,
          child: const Text('Dashboard'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(FirstTimeSetupScreen), findsNothing);
    expect(store.completed, isTrue);
    expect(
      await database.select(database.categories).get(),
      hasLength(defaultCategoryCatalog.length),
    );
  });

  testWidgets('a previously skipped setup is not shown again',
      (tester) async {
    store.completed = true;

    await tester.pumpWidget(
      MaterialApp(
        home: FirstTimeSetupGate(
          database: database,
          store: store,
          child: const Text('Dashboard'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(FirstTimeSetupScreen), findsNothing);
  });
}
