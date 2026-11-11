import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores the first-run onboarding state privately on this device.
/// This is deliberately separate from the financial database, so no Drift
/// schema migration is required.
class OnboardingCompletionStore {
  static const String _markerFileName = 'getting_started_completed';

  static Future<bool> hasCompleted() async {
    try {
      final directory = await getApplicationSupportDirectory();
      return await File(p.join(directory.path, _markerFileName)).exists();
    } catch (_) {
      // Treat an unavailable marker as not completed. The user can still
      // enter the app, and completion will be retried when the screen ends.
      return false;
    }
  }

  static Future<void> markCompleted() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final marker = File(p.join(directory.path, _markerFileName));
    await marker.writeAsString('completed', flush: true);
  }
}
