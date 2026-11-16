import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_alert.dart';

/// Everything the alerts feature remembers between launches.
class AlertState {
  final List<AppAlert> alerts;

  /// The user's master switch for notifications shown outside the app.
  final bool notificationsEnabled;

  /// Whether the system permission prompt has already been shown once.
  final bool permissionAsked;

  /// Alert keys that had an OS-scheduled notification at the last refresh. If
  /// such an alert first shows up later, the OS has already told the user, so
  /// the app must not notify a second time.
  final Set<String> scheduledKeys;

  const AlertState({
    this.alerts = const [],
    this.notificationsEnabled = true,
    this.permissionAsked = false,
    this.scheduledKeys = const {},
  });

  int get unreadCount => alerts.where((alert) => !alert.isRead).length;

  AlertState copyWith({
    List<AppAlert>? alerts,
    bool? notificationsEnabled,
    bool? permissionAsked,
    Set<String>? scheduledKeys,
  }) {
    return AlertState(
      alerts: alerts ?? this.alerts,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      permissionAsked: permissionAsked ?? this.permissionAsked,
      scheduledKeys: scheduledKeys ?? this.scheduledKeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'notificationsEnabled': notificationsEnabled,
    'permissionAsked': permissionAsked,
    'scheduledKeys': scheduledKeys.toList()..sort(),
    'alerts': alerts.map((alert) => alert.toJson()).toList(),
  };

  static AlertState fromJson(Map<String, dynamic> json) {
    final rawAlerts = json['alerts'];
    final alerts = <AppAlert>[];
    if (rawAlerts is List) {
      for (final raw in rawAlerts) {
        final alert = AppAlert.fromJson(raw);
        if (alert != null) alerts.add(alert);
      }
    }
    final rawKeys = json['scheduledKeys'];
    return AlertState(
      alerts: alerts,
      notificationsEnabled: json['notificationsEnabled'] != false,
      permissionAsked: json['permissionAsked'] == true,
      scheduledKeys: rawKeys is List
          ? rawKeys.whereType<String>().toSet()
          : const {},
    );
  }
}

/// Keeps [AlertState] in a small JSON file in app-private storage, next to the
/// backup settings. No database migration is needed.
class AlertStore {
  final Future<Directory> Function()? documentsDirectoryProvider;

  AlertStore({this.documentsDirectoryProvider});

  Future<File> _file() async {
    final provider = documentsDirectoryProvider;
    final documents = provider == null
        ? await getApplicationDocumentsDirectory()
        : await provider();
    return File(p.join(documents.path, 'Artham', 'alerts.json'));
  }

  Future<AlertState> load() async {
    final file = await _file();
    if (!await file.exists()) return const AlertState();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const AlertState();
      return AlertState.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // A damaged file must never stop the app from starting.
      return const AlertState();
    }
  }

  Future<void> save(AlertState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toJson()),
      encoding: utf8,
      flush: true,
    );
  }
}
