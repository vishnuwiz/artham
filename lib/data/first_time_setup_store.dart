import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists whether the optional first-time setup has been completed or skipped.
/// This is separate from the financial database and needs no Drift migration.
abstract interface class FirstTimeSetupStore {
  Future<bool> hasCompleted();
  Future<void> markCompleted();
}

class LocalFirstTimeSetupStore implements FirstTimeSetupStore {
  static const String _markerFileName = 'first_time_setup_completed';

  @override
  Future<bool> hasCompleted() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return await File(p.join(directory.path, _markerFileName)).exists();
    } catch (_) {
      // An unavailable marker should never prevent the user from opening Artham.
      return false;
    }
  }

  @override
  Future<void> markCompleted() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final marker = File(p.join(directory.path, _markerFileName));
    await marker.writeAsString('completed', flush: true);
  }
}
