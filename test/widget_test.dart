import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/data/app_database.dart';
import 'package:artham/main.dart';
import 'package:artham/theme/artham_theme.dart';

void main() {
  late AppDatabase testDatabase;

  setUp(() {
    testDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    initializeAppDatabaseForTesting(testDatabase);
  });

  tearDown(() async {
    await testDatabase.close();
  });

  testWidgets('Artham navigation opens the bank SMS import review screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ArthamApp());
    // The initial dashboard and offstage tabs may contain indeterminate
    // loading indicators, so do not wait for every animation to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Artham'), findsOneWidget);
    expect(find.byType(ArthamTabBar), findsOneWidget);

    final activityDestination = find.descendant(
      of: find.byType(ArthamTabBar),
      matching: find.text('Activity'),
    );
    await tester.tap(activityDestination);
    // The Activity screen can keep a progress indicator animating while its
    // database query completes. Pump the tab transition without requiring
    // every offstage animation to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final importButton = find.byTooltip('Import bank SMS');
    expect(importButton, findsOneWidget);

    await tester.tap(importButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Import bank SMS'), findsOneWidget);
    expect(find.text('Parse message'), findsOneWidget);
    expect(
      find.textContaining('original message is not saved'),
      findsOneWidget,
    );
  });
}
