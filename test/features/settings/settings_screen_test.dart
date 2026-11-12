import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/features/settings/categories_screen.dart';
import 'package:artham/features/settings/settings_screen.dart';
import 'package:artham/theme/artham_theme.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('keeps category management and adds JSON restore controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: SettingsScreen(database: database),
      ),
    );

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Manage categories'), findsOneWidget);
    expect(find.text('Export your data'), findsOneWidget);
    expect(find.text('Save JSON'), findsOneWidget);
    expect(find.text('Restore from JSON backup'), findsOneWidget);
  });

  testWidgets('category management still opens from Settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: SettingsScreen(database: database),
      ),
    );

    await tester.tap(find.text('Manage categories'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);
  });
}
