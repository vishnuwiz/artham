import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/settings/data_export_screen.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('shows CSV export, date range and JSON backup options',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataExportScreen(database: database),
      ),
    );
    await tester.pump();

    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Transactions CSV'), findsOneWidget);
    expect(find.text('Full financial backup'), findsOneWidget);
    expect(find.text('Export transactions (CSV)'), findsOneWidget);
    expect(find.text('Export full backup (JSON)'), findsOneWidget);

    await tester.tap(find.text('Limit export to a date range'));
    await tester.pump();

    expect(find.textContaining('From '), findsOneWidget);
    expect(find.textContaining('To '), findsOneWidget);
  });
}
