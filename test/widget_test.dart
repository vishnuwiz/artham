import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/main.dart';

void main() {
  late AppDatabase testDatabase;

  setUp(() {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    initializeAppDatabaseForTesting(testDatabase);
  });

  tearDown(() async {
    await testDatabase.close();
  });

  testWidgets('Artham navigation opens the bank SMS import review screen',
      (tester) async {
    await tester.pumpWidget(const ArthamApp());
    await tester.pumpAndSettle();

    expect(find.text('Artham'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    final activityDestination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Activity'),
    );
    await tester.tap(activityDestination);
    await tester.pumpAndSettle();

    final importButton = find.byTooltip('Import bank SMS');
    expect(importButton, findsOneWidget);

    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(find.text('Import bank SMS'), findsOneWidget);
    expect(find.text('Parse message'), findsOneWidget);
    expect(
      find.textContaining('original message is not saved'),
      findsOneWidget,
    );
  });
}
