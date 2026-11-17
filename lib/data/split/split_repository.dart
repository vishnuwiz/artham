import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../app_database.dart';
import 'split_models.dart';
import 'split_sources.dart';
import 'split_store.dart';

/// One person's slice of a bill. [personId] is null for you.
class SplitShare {
  final String? personId;
  final int paise;

  const SplitShare({required this.personId, required this.paise});
}

/// Reads and changes the shared-money ledger, and records the matching rows
/// in the transactions table so account balances stay correct.
///
/// Your own share of a bill is a normal expense. The part you paid on behalf
/// of others and any repayments are tagged with a `split_*` source, which the
/// spending, budget and insight totals skip.
class SplitRepository {
  SplitRepository(
    this.database, {
    SplitStore? store,
    Future<Directory> Function()? documentsDirectoryProvider,
    DateTime Function()? clock,
  }) : store =
           store ??
           SplitStore(documentsDirectoryProvider: documentsDirectoryProvider),
       _clock = clock ?? DateTime.now;

  final AppDatabase database;
  final SplitStore store;
  final DateTime Function() _clock;

  /// Net amount owed to you, for the Home card. Updated after every change.
  final ValueNotifier<SplitLedger> ledger = ValueNotifier(const SplitLedger());

  Future<void> _tail = Future<void>.value();
  int _counter = 0;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String _newId() {
    _counter += 1;
    return '${_clock().microsecondsSinceEpoch.toRadixString(36)}$_counter';
  }

  /// Loads the ledger, dropping any group whose linked transaction was deleted
  /// from Activity so the ledger never claims money that is no longer there.
  Future<SplitLedger> load() => _serial(() async {
    try {
      final loaded = await _loadReconciled();
      ledger.value = loaded;
      return loaded;
    } catch (_) {
      // Storage being unavailable must never break the screens that call this.
      return ledger.value;
    }
  });

  Future<SplitLedger> _loadReconciled() async {
    final stored = await store.load();
    final wanted = <int>{
      for (final entry in stored.entries) ...entry.transactionIds,
    };
    if (wanted.isEmpty) return stored;

    final rows = await (database.select(
      database.moneyTransactions,
    )..where((t) => t.id.isIn(wanted.toList()))).get();
    final existing = rows.map((row) => row.id).toSet();

    final brokenGroups = <String>{
      for (final entry in stored.entries)
        if (entry.transactionIds.any((id) => !existing.contains(id)))
          entry.groupId,
    };
    if (brokenGroups.isEmpty) return stored;

    final cleaned = SplitLedger(
      people: stored.people,
      entries: stored.entries
          .where((entry) => !brokenGroups.contains(entry.groupId))
          .toList(),
    );
    await store.save(cleaned);
    return cleaned;
  }

  Future<void> _commit(SplitLedger next) async {
    await store.save(next);
    ledger.value = next;
  }

  /// Adds a person, or returns the existing one with the same name.
  Future<SplitPerson> addPerson(String name) => _serial(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Enter a name');
    }
    final current = await _loadReconciled();
    for (final person in current.people) {
      if (person.name.toLowerCase() == trimmed.toLowerCase()) return person;
    }
    final person = SplitPerson(
      id: _newId(),
      name: trimmed,
      colorIndex: current.people.length,
      createdAt: _clock(),
    );
    await _commit(
      SplitLedger(people: [...current.people, person], entries: current.entries),
    );
    return person;
  });

  /// Records a bill you paid and shared. [shares] must add up to
  /// [totalPaise]; the entry with a null person is your own share.
  Future<void> addSplitExpense({
    required String title,
    required int totalPaise,
    required int accountId,
    required int? categoryId,
    required DateTime date,
    required List<SplitShare> shares,
  }) => _serial(() async {
    if (totalPaise <= 0) throw ArgumentError('Enter an amount');
    final sum = shares.fold<int>(0, (a, b) => a + b.paise);
    if (sum != totalPaise) {
      throw ArgumentError('Shares must add up to the total');
    }
    final others = shares.where((s) => s.personId != null && s.paise > 0);
    if (others.isEmpty) throw ArgumentError('Pick someone to split with');
    final myShare = shares
        .where((s) => s.personId == null)
        .fold<int>(0, (a, b) => a + b.paise);
    final lentTotal = totalPaise - myShare;
    final cleanTitle = title.trim().isEmpty ? 'Shared expense' : title.trim();

    final current = await _loadReconciled();
    final groupId = _newId();
    final txIds = <int>[];

    await database.transaction(() async {
      if (myShare > 0) {
        txIds.add(
          await database
              .into(database.moneyTransactions)
              .insert(
                MoneyTransactionsCompanion.insert(
                  accountId: accountId,
                  categoryId: Value(categoryId),
                  amountPaise: myShare,
                  transactionType: 'expense',
                  transactionDate: date,
                  description: Value('$cleanTitle (your share)'),
                  source: const Value('manual'),
                ),
              ),
        );
      }
      txIds.add(
        await database
            .into(database.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                accountId: accountId,
                amountPaise: lentTotal,
                transactionType: 'expense',
                transactionDate: date,
                description: Value('$cleanTitle (paid for others)'),
                source: const Value(kSplitLentSource),
              ),
            ),
      );
    });

    final newEntries = [
      for (final share in others)
        SplitEntry(
          id: _newId(),
          personId: share.personId!,
          kind: SplitEntryKind.lent,
          amountPaise: share.paise,
          title: cleanTitle,
          date: date,
          groupId: groupId,
          transactionIds: txIds,
          billPaise: totalPaise,
        ),
    ];
    await _commit(
      SplitLedger(
        people: current.people,
        entries: [...current.entries, ...newEntries],
      ),
    );
  });

  /// Notes that someone else paid and you owe your share. It only changes the
  /// ledger; no money has left your accounts yet.
  Future<void> addOwedByYou({
    required String personId,
    required int amountPaise,
    required String title,
    required DateTime date,
  }) => _serial(() async {
    if (amountPaise <= 0) throw ArgumentError('Enter an amount');
    final current = await _loadReconciled();
    final id = _newId();
    final entry = SplitEntry(
      id: id,
      personId: personId,
      kind: SplitEntryKind.borrowed,
      amountPaise: amountPaise,
      title: title.trim().isEmpty ? 'Shared expense' : title.trim(),
      date: date,
      groupId: id,
    );
    await _commit(
      SplitLedger(
        people: current.people,
        entries: [...current.entries, entry],
      ),
    );
  });

  /// Records a repayment. [receivedFromThem] is true when they paid you.
  Future<void> settle({
    required String personId,
    required int amountPaise,
    required bool receivedFromThem,
    required int accountId,
    required DateTime date,
  }) => _serial(() async {
    if (amountPaise <= 0) throw ArgumentError('Enter an amount');
    final current = await _loadReconciled();
    final person = current.personById(personId);
    if (person == null) throw ArgumentError('Unknown person');

    final txId = await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            accountId: accountId,
            amountPaise: amountPaise,
            transactionType: receivedFromThem ? 'income' : 'expense',
            transactionDate: date,
            description: Value(
              receivedFromThem
                  ? '${person.name} paid you back'
                  : 'Paid back ${person.name}',
            ),
            source: Value(
              receivedFromThem ? kSplitReceivedSource : kSplitPaidBackSource,
            ),
          ),
        );

    final id = _newId();
    final entry = SplitEntry(
      id: id,
      personId: personId,
      kind: receivedFromThem
          ? SplitEntryKind.received
          : SplitEntryKind.paidBack,
      amountPaise: amountPaise,
      title: receivedFromThem
          ? '${person.name} paid you back'
          : 'You paid ${person.name} back',
      date: date,
      groupId: id,
      transactionIds: [txId],
    );
    await _commit(
      SplitLedger(
        people: current.people,
        entries: [...current.entries, entry],
      ),
    );
  });

  /// Removes one line (or the whole split it belongs to) and the transactions
  /// it created.
  Future<void> deleteGroup(String groupId) => _serial(() async {
    final current = await _loadReconciled();
    final removed = current.entries.where((e) => e.groupId == groupId).toList();
    if (removed.isEmpty) return;
    final txIds = <int>{for (final e in removed) ...e.transactionIds};
    if (txIds.isNotEmpty) {
      await (database.delete(
        database.moneyTransactions,
      )..where((t) => t.id.isIn(txIds.toList()))).go();
    }
    await _commit(
      SplitLedger(
        people: current.people,
        entries: current.entries.where((e) => e.groupId != groupId).toList(),
      ),
    );
  });

  /// Removes a person only when nothing is outstanding. Their past lines
  /// leave the ledger; the transactions already recorded stay as they are.
  Future<bool> removePersonIfSettled(String personId) => _serial(() async {
    final current = await _loadReconciled();
    if (current.balanceFor(personId) != 0) return false;
    await _commit(
      SplitLedger(
        people: current.people.where((p) => p.id != personId).toList(),
        entries: current.entries.where((e) => e.personId != personId).toList(),
      ),
    );
    return true;
  });
}
