import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/user_profile.dart';
import 'package:artham/features/onboarding/name_gate.dart';

void main() {
  testWidgets('asks for a name once, then shows the app', (tester) async {
    late Directory dir;
    late UserProfile profile;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('name_gate_test');
      profile = UserProfile(directoryProvider: () async => dir);
    });
    addTearDown(() => dir.delete(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: NameGate(profile: profile, child: const Text('HOME')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.enterText(find.byKey(const Key('name-field')), 'Vishnu');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining(', Vishnu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('name-continue-button')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('HOME'), findsOneWidget);
    expect(profile.name.value, 'Vishnu');
  });

  testWidgets('skipping goes straight to the app without a name', (
    tester,
  ) async {
    late Directory dir;
    late UserProfile profile;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('name_gate_skip_test');
      profile = UserProfile(directoryProvider: () async => dir);
    });
    addTearDown(() => dir.delete(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        home: NameGate(profile: profile, child: const Text('HOME')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.byKey(const Key('name-skip-button')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('HOME'), findsOneWidget);
    expect(profile.name.value, isNull);
    expect(profile.asked, isTrue);
  });
}
