import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artham/theme/artham_theme.dart';

void main() {
  testWidgets('tab switcher cross-fades and keeps hidden pages mounted', (
    tester,
  ) async {
    Widget build(int index) => MaterialApp(
      home: Scaffold(
        body: ArthamTabSwitcher(
          index: index,
          children: const [Text('First page'), Text('Second page')],
        ),
      ),
    );

    await tester.pumpWidget(build(0));
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Second page'), findsNothing);
    expect(find.text('Second page', skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(build(1));
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transition both pages are painted.
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Second page'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('First page'), findsNothing);
    expect(find.text('First page', skipOffstage: false), findsOneWidget);
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('tab bar capsule slides to the selected tab', (tester) async {
    Widget build(int index) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ArthamTabBar(
          selectedIndex: index,
          onSelected: (_) {},
          tabs: const [
            ArthamTab(icon: Icons.home_outlined, label: 'One'),
            ArthamTab(icon: Icons.settings_outlined, label: 'Two'),
          ],
        ),
      ),
    );

    await tester.pumpWidget(build(0));
    final before = tester
        .getTopLeft(find.byKey(const ValueKey('artham-tab-capsule')))
        .dx;
    await tester.pumpWidget(build(1));
    await tester.pump(const Duration(milliseconds: 120));
    final during = tester
        .getTopLeft(find.byKey(const ValueKey('artham-tab-capsule')))
        .dx;
    await tester.pump(const Duration(milliseconds: 600));
    final after = tester
        .getTopLeft(find.byKey(const ValueKey('artham-tab-capsule')))
        .dx;

    expect(during, greaterThan(before));
    expect(after, greaterThan(during));
  });
}
