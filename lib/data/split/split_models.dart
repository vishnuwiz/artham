/// What kind of money movement a ledger line records. Amounts are in paise.
enum SplitEntryKind {
  /// You paid, they owe you their share. Raises what they owe.
  lent,

  /// They paid, you owe your share. Lowers what they owe.
  borrowed,

  /// They paid you back. Lowers what they owe.
  received,

  /// You paid them back. Raises what they owe (towards zero when you owed).
  paidBack,
}

SplitEntryKind? _kindFromName(Object? name) {
  for (final kind in SplitEntryKind.values) {
    if (kind.name == name) return kind;
  }
  return null;
}

class SplitPerson {
  final String id;
  final String name;

  /// Index into the avatar palette, so a person keeps the same colour.
  final int colorIndex;
  final DateTime createdAt;

  const SplitPerson({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
  });

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'createdAt': createdAt.toIso8601String(),
  };

  static SplitPerson? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final created = DateTime.tryParse('${raw['createdAt']}');
    if (id is! String || name is! String || created == null) return null;
    final color = raw['colorIndex'];
    return SplitPerson(
      id: id,
      name: name,
      colorIndex: color is int ? color : 0,
      createdAt: created,
    );
  }
}

class SplitEntry {
  final String id;
  final String personId;
  final SplitEntryKind kind;
  final int amountPaise;
  final String title;
  final DateTime date;

  /// Entries created by one split expense share a group, so deleting the
  /// expense removes every person's line together.
  final String groupId;

  /// Rows in the transactions table that this line is tied to. Empty for a
  /// ledger-only note such as "Meera paid for dinner".
  final List<int> transactionIds;

  /// The total bill, kept so the history can say "you paid ₹2,400".
  final int? billPaise;

  const SplitEntry({
    required this.id,
    required this.personId,
    required this.kind,
    required this.amountPaise,
    required this.title,
    required this.date,
    required this.groupId,
    this.transactionIds = const [],
    this.billPaise,
  });

  /// Effect on "they owe you": positive raises it, negative lowers it.
  int get signedPaise {
    switch (kind) {
      case SplitEntryKind.lent:
      case SplitEntryKind.paidBack:
        return amountPaise;
      case SplitEntryKind.borrowed:
      case SplitEntryKind.received:
        return -amountPaise;
    }
  }

  bool get isSettlement =>
      kind == SplitEntryKind.received || kind == SplitEntryKind.paidBack;

  Map<String, dynamic> toJson() => {
    'id': id,
    'personId': personId,
    'kind': kind.name,
    'amountPaise': amountPaise,
    'title': title,
    'date': date.toIso8601String(),
    'groupId': groupId,
    'transactionIds': transactionIds,
    if (billPaise != null) 'billPaise': billPaise,
  };

  static SplitEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final personId = raw['personId'];
    final kind = _kindFromName(raw['kind']);
    final amount = raw['amountPaise'];
    final date = DateTime.tryParse('${raw['date']}');
    if (id is! String ||
        personId is! String ||
        kind == null ||
        amount is! int ||
        amount <= 0 ||
        date == null) {
      return null;
    }
    final ids = raw['transactionIds'];
    final bill = raw['billPaise'];
    return SplitEntry(
      id: id,
      personId: personId,
      kind: kind,
      amountPaise: amount,
      title: raw['title'] is String ? raw['title'] as String : '',
      date: date,
      groupId: raw['groupId'] is String ? raw['groupId'] as String : id,
      transactionIds: ids is List ? ids.whereType<int>().toList() : const [],
      billPaise: bill is int ? bill : null,
    );
  }
}

/// The whole shared-money picture: people plus every line between you.
class SplitLedger {
  final List<SplitPerson> people;
  final List<SplitEntry> entries;

  const SplitLedger({this.people = const [], this.entries = const []});

  SplitPerson? personById(String id) {
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  List<SplitEntry> entriesFor(String personId) {
    final list = entries.where((entry) => entry.personId == personId).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return list;
  }

  /// Positive: they owe you. Negative: you owe them.
  int balanceFor(String personId) => entries
      .where((entry) => entry.personId == personId)
      .fold<int>(0, (sum, entry) => sum + entry.signedPaise);

  int get totalOwedToYou => people
      .map((person) => balanceFor(person.id))
      .where((balance) => balance > 0)
      .fold<int>(0, (sum, balance) => sum + balance);

  int get totalYouOwe => people
      .map((person) => balanceFor(person.id))
      .where((balance) => balance < 0)
      .fold<int>(0, (sum, balance) => sum - balance);

  int get peopleWhoOweYou =>
      people.where((person) => balanceFor(person.id) > 0).length;

  int get peopleYouOwe =>
      people.where((person) => balanceFor(person.id) < 0).length;

  bool get isEmpty => people.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'people': people.map((person) => person.toJson()).toList(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  static SplitLedger fromJson(Map<String, dynamic> json) {
    final people = <SplitPerson>[];
    final rawPeople = json['people'];
    if (rawPeople is List) {
      for (final raw in rawPeople) {
        final person = SplitPerson.fromJson(raw);
        if (person != null) people.add(person);
      }
    }
    final known = people.map((person) => person.id).toSet();
    final entries = <SplitEntry>[];
    final rawEntries = json['entries'];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        final entry = SplitEntry.fromJson(raw);
        if (entry != null && known.contains(entry.personId)) {
          entries.add(entry);
        }
      }
    }
    return SplitLedger(people: people, entries: entries);
  }
}

/// How the bill is divided between the people at the table.
enum SplitMode { equal, amounts, percent }

/// Divides [totalPaise] between [count] people. The leftover paise from an
/// uneven division go one each to the first people, so the shares always add
/// up to exactly [totalPaise].
List<int> splitEqually(int totalPaise, int count) {
  if (count <= 0) return const [];
  final base = totalPaise ~/ count;
  final extra = totalPaise - base * count;
  return [for (var i = 0; i < count; i++) base + (i < extra ? 1 : 0)];
}

/// Turns percentages (whole or fractional) into paise that add up to exactly
/// [totalPaise]. The caller checks the percentages add up to 100.
List<int> splitByPercent(int totalPaise, List<double> percents) {
  if (percents.isEmpty) return const [];
  final raw = [for (final p in percents) totalPaise * p / 100];
  final shares = [for (final r in raw) r.floor()];
  var leftover = totalPaise - shares.fold<int>(0, (a, b) => a + b);
  // Hand the leftover to the largest fractional remainders first.
  final order = List<int>.generate(raw.length, (i) => i)
    ..sort((a, b) => (raw[b] - shares[b]).compareTo(raw[a] - shares[a]));
  for (final index in order) {
    if (leftover <= 0) break;
    shares[index] += 1;
    leftover -= 1;
  }
  return shares;
}
