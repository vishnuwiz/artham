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

  testWidgets('Artham app renders its main navigation', (tester) async {
    await tester.pumpWidget(const ArthamApp());
    await tester.pumpAndSettle();

    expect(find.text('Artham'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
