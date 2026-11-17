import 'package:artham/data/split/split_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equal split always adds up and spreads leftover paise', () {
    final shares = splitEqually(10000, 3);
    expect(shares, [3334, 3333, 3333]);
    expect(shares.fold<int>(0, (a, b) => a + b), 10000);
    expect(splitEqually(240000, 4), [60000, 60000, 60000, 60000]);
    expect(splitEqually(100, 0), isEmpty);
  });

  test('percent split adds up exactly', () {
    final shares = splitByPercent(10000, [33.3, 33.3, 33.4]);
    expect(shares.fold<int>(0, (a, b) => a + b), 10000);
    expect(shares, [3330, 3330, 3340]);
    final odd = splitByPercent(1001, [50, 50]);
    expect(odd.fold<int>(0, (a, b) => a + b), 1001);
  });

  test('balances combine lent, received, borrowed and paid back', () {
    final now = DateTime(2026, 11, 16);
    SplitEntry entry(String id, String person, SplitEntryKind kind, int paise) =>
        SplitEntry(
          id: id,
          personId: person,
          kind: kind,
          amountPaise: paise,
          title: 't',
          date: now,
          groupId: id,
        );
    final ledger = SplitLedger(
      people: [
        SplitPerson(id: 'm', name: 'Meera', colorIndex: 0, createdAt: now),
        SplitPerson(id: 'a', name: 'Arjun', colorIndex: 1, createdAt: now),
      ],
      entries: [
        entry('1', 'm', SplitEntryKind.lent, 85000),
        entry('2', 'm', SplitEntryKind.lent, 40000),
        entry('3', 'm', SplitEntryKind.received, 60000),
        entry('4', 'a', SplitEntryKind.borrowed, 80000),
      ],
    );
    expect(ledger.balanceFor('m'), 65000);
    expect(ledger.balanceFor('a'), -80000);
    expect(ledger.totalOwedToYou, 65000);
    expect(ledger.totalYouOwe, 80000);
    expect(ledger.peopleWhoOweYou, 1);
    expect(ledger.peopleYouOwe, 1);
  });

  test('ledger survives a JSON round trip and skips damaged rows', () {
    final now = DateTime(2026, 11, 16);
    final ledger = SplitLedger(
      people: [SplitPerson(id: 'm', name: 'Meera', colorIndex: 2, createdAt: now)],
      entries: [
        SplitEntry(
          id: 'e',
          personId: 'm',
          kind: SplitEntryKind.lent,
          amountPaise: 500,
          title: 'Lunch',
          date: now,
          groupId: 'g',
          transactionIds: const [3, 4],
          billPaise: 1000,
        ),
      ],
    );
    final json = ledger.toJson();
    (json['entries'] as List).add({'id': 'bad'});
    (json['entries'] as List).add({
      'id': 'x',
      'personId': 'ghost',
      'kind': 'lent',
      'amountPaise': 5,
      'date': now.toIso8601String(),
    });
    final copy = SplitLedger.fromJson(json);
    expect(copy.people.single.name, 'Meera');
    expect(copy.entries.single.transactionIds, [3, 4]);
    expect(copy.entries.single.billPaise, 1000);
  });
}
