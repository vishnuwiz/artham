import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// "Good morning", "Good afternoon" or "Good evening" for the given time.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// The name the user wants to be greeted by. It is kept in a small private
/// file, separate from the financial database, so no schema change is needed.
class UserProfile {
  UserProfile({this.directoryProvider});

  static final UserProfile instance = UserProfile();

  static const int maxNameLength = 24;

  final Future<Directory> Function()? directoryProvider;

  /// The saved name, or null when none was given.
  final ValueNotifier<String?> name = ValueNotifier<String?>(null);

  /// True once the user has answered the name question, even by skipping it.
  bool asked = false;

  /// Trims, collapses spaces and limits the length. Empty becomes null.
  static String? clean(String? raw) {
    final value = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return null;
    return value.length > maxNameLength
        ? value.substring(0, maxNameLength).trim()
        : value;
  }

  Future<File> _file() async {
    final provider = directoryProvider;
    final directory = provider == null
        ? await getApplicationSupportDirectory()
        : await provider();
    return File(p.join(directory.path, 'profile.json'));
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        name.value = clean(decoded['name'] as String?);
        asked = decoded['asked'] == true;
      }
    } catch (_) {
      // A missing or damaged file just means we ask again.
    }
  }

  /// Saves [value] as the name. Passing null records that the user skipped.
  Future<void> save(String? value) async {
    name.value = clean(value);
    asked = true;
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({'name': name.value, 'asked': true}),
        flush: true,
      );
    } catch (error) {
      // Not being able to remember the name must never block the app.
      debugPrint('Artham profile could not be saved: $error');
    }
  }
}
