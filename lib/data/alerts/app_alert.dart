/// The kinds of alert Artham can raise. Everything is generated on this phone
/// from local data; nothing is sent to a server.
enum AlertKind { budget, recurring, backup, summary }

class AppAlert {
  /// Stable identity, e.g. `budget-overall-2026-11`. A key is only ever turned
  /// into one alert, so re-running the checks never duplicates it.
  final String key;
  final AlertKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const AppAlert({
    required this.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  AppAlert copyWith({String? title, String? body, bool? isRead}) {
    return AppAlert(
      key: key,
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'isRead': isRead,
  };

  /// Returns null for damaged entries so one bad record cannot hide the rest.
  static AppAlert? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final kindName = raw['kind'];
    final title = raw['title'];
    final body = raw['body'];
    final createdAt = raw['createdAt'] is String
        ? DateTime.tryParse(raw['createdAt'] as String)
        : null;
    if (key is! String || title is! String || body is! String) return null;
    if (createdAt == null) return null;

    AlertKind? kind;
    for (final candidate in AlertKind.values) {
      if (candidate.name == kindName) kind = candidate;
    }
    if (kind == null) return null;

    return AppAlert(
      key: key,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt.toLocal(),
      isRead: raw['isRead'] == true,
    );
  }
}
