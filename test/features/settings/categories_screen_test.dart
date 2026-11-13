import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/repositories/category_repository.dart';
import 'package:artham/features/settings/categories_screen.dart';
import 'package:artham/features/settings/settings_screen.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings opens Categories and a new category can be added', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late AppDatabase database;
    await tester.runAsync(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Self Transfer',
              type: 'expense',
              isSystem: const Value(true),
              seedKey: const Value('expense.self_transfer'),
            ),
          );
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Self Transfer',
              type: 'income',
              isSystem: const Value(true),
              seedKey: const Value('income.self_transfer'),
            ),
          );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: SettingsScreen(database: database),
      ),
    );
    await tester.tap(find.byKey(const Key('manage-categories-button')));
    await settle(tester);

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Food & Grocery'), findsOneWidget);
    expect(find.text('Self Transfer'), findsNothing);

    // Income tab shows the income defaults.
    await tester.tap(find.text('Income').first);
    await settle(tester);
    expect(find.text('Reimbursement'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Self Transfer'), findsNothing);

    // Back to Expense and add a custom category.
    await tester.tap(find.text('Expense').first);
    await settle(tester);
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Pet care',
    );
    await tester.tap(find.byIcon(Icons.pets_rounded));
    await tester.tap(find.text('Add category'));
    await settle(tester);

    expect(find.text('Pet care'), findsOneWidget);

    final saved = await tester.runAsync(
      () => CategoryRepository(database).getCategories('expense'),
    );
    final petCare = saved!.firstWhere((item) => item.name == 'Pet care');
    expect(petCare.iconKey, 'pets');

    await tester.runAsync(() => database.close());
  });
}
