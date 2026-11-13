import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('shows the glass settings layout and supported actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: SettingsScreen(database: database),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Manage your Artham experience'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Export your data'), findsOneWidget);
    // Export controls are intentionally hidden until the compact card is expanded.

    expect(find.byKey(const Key('share-csv-button')), findsNothing);
    expect(find.byKey(const Key('save-csv-button')), findsNothing);
    expect(find.byKey(const Key('share-json-button')), findsNothing);
    expect(find.byKey(const Key('save-json-button')), findsNothing);
    expect(find.byKey(const Key('restore-json-backup-button')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Backup management'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Backup management'), findsOneWidget);
    expect(find.text('View backups and manage storage.'), findsOneWidget);

    // Unsupported preferences and system-storage controls are deliberately
    // not shown as inactive or placeholder rows.
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('App language'), findsNothing);
    expect(find.text('App storage'), findsNothing);
    expect(find.text('About Artham'), findsNothing);
  });

  testWidgets('export section starts collapsed and can be expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: SettingsScreen(database: database),
      ),
    );

    final header = find.byKey(const Key('settings-export-header'));
    expect(find.byKey(const Key('share-csv-button')), findsNothing);
    expect(find.byKey(const Key('save-csv-button')), findsNothing);
    expect(find.byKey(const Key('share-json-button')), findsNothing);
    expect(find.byKey(const Key('save-json-button')), findsNothing);
    expect(find.byKey(const Key('restore-json-backup-button')), findsNothing);

    await tester.tap(header);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share-csv-button')), findsOneWidget);
    expect(find.byKey(const Key('save-csv-button')), findsOneWidget);
    expect(find.byKey(const Key('share-json-button')), findsOneWidget);
    expect(find.byKey(const Key('save-json-button')), findsOneWidget);
    expect(find.byKey(const Key('restore-json-backup-button')), findsOneWidget);
    expect(
      find.text('JSON backups are not encrypted. Store backup files securely.'),
      findsOneWidget,
    );

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-csv-button')), findsNothing);
  });
  testWidgets('category management still opens from Settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArthamTheme(),
        home: SettingsScreen(database: database),
      ),
    );

    await tester.tap(find.byKey(const Key('settings-categories-row')));
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);
  });
}
