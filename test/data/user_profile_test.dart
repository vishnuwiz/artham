import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:artham/data/user_profile.dart';

void main() {
  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 11, 19, 9)), 'Good morning');
    expect(greetingFor(DateTime(2026, 11, 19, 14)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 11, 19, 20)), 'Good evening');
  });

  test('clean trims, collapses spaces and limits length', () {
    expect(UserProfile.clean('  Vishnu   S '), 'Vishnu S');
    expect(UserProfile.clean('   '), isNull);
    expect(UserProfile.clean(null), isNull);
    expect(UserProfile.clean('a' * 40)!.length, UserProfile.maxNameLength);
  });

  test('name and the answered flag are saved and loaded again', () async {
    final dir = await Directory.systemTemp.createTemp('profile_test');
    addTearDown(() => dir.delete(recursive: true));
    final profile = UserProfile(directoryProvider: () async => dir);
    await profile.load();
    expect(profile.asked, isFalse);
    expect(profile.name.value, isNull);

    await profile.save('Vishnu');
    final again = UserProfile(directoryProvider: () async => dir);
    await again.load();
    expect(again.asked, isTrue);
    expect(again.name.value, 'Vishnu');

    await again.save(null);
    final skipped = UserProfile(directoryProvider: () async => dir);
    await skipped.load();
    expect(skipped.asked, isTrue);
    expect(skipped.name.value, isNull);
  });
}
