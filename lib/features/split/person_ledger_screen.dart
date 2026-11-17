import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_database.dart';
import '../../data/split/split_models.dart';
import '../../data/split/split_repository.dart';
import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import 'settle_sheet.dart';
import 'split_shared.dart';

/// Everything between you and one person, with a way to settle up.
class PersonLedgerScreen extends StatelessWidget {
  const PersonLedgerScreen({
    super.key,
    required this.repository,
    required this.database,
    required this.personId,
  });

  final SplitRepository repository;
  final AppDatabase database;
  final String personId;

  Future<void> _settle(BuildContext context, SplitPerson person, int balance) async {
    final done = await showSettleSheet(
      context,
      repository: repository,
      database: database,
      person: person,
      balancePaise: balance,
    );
    if (done == true && context.mounted) await showSavedCheck(context);
  }

  Future<void> _remind(SplitPerson person, int balance) async {
    final text =
        'Hi ${person.name}, a quick reminder that you owe me '
        '${splitMoney(balance)} for our shared expenses. Thanks!';
    await SharePlus.instance.share(
      ShareParams(text: text, title: 'Reminder for ${person.name}'),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, SplitEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArthamColors.sheet,
        title: const Text(
          'Delete this entry?',
          style: TextStyle(color: ArthamColors.text),
        ),
        content: Text(
          entry.isSettlement
              ? 'The repayment and its transaction will be removed.'
              : 'This removes the whole split for everyone, and the '
                    'transactions it created.',
          style: const TextStyle(color: ArthamColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await repository.deleteGroup(entry.groupId);
    HapticFeedback.mediumImpact();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      body: SafeArea(
        child: ValueListenableBuilder<SplitLedger>(
          valueListenable: repository.ledger,
          builder: (context, ledger, _) {
            final person = ledger.personById(personId);
            if (person == null) {
              return const Center(
                child: Text(
                  'This person is no longer in your list.',
                  style: TextStyle(color: ArthamColors.muted),
                ),
              );
            }
            final balance = ledger.balanceFor(personId);
            final entries = ledger.entriesFor(personId);
            final owesYou = balance > 0;
            final settled = balance == 0;
            final accent = settled
                ? ArthamColors.lavender
                : owesYou
                ? ArthamColors.mint
                : ArthamColors.debit;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        person.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ArthamColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppearIn(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: ArthamColors.heroGradient,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: ArthamColors.line),
                    ),
                    child: Column(
                      children: [
                        SplitAvatar(person: person, size: 60, hero: true),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            settled
                                ? 'You are all square'
                                : owesYou
                                ? '${person.name} owes you'
                                : 'You owe ${person.name}',
                            key: ValueKey('$settled$owesYou'),
                            style: const TextStyle(
                              color: ArthamColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        AnimatedMoney(
                          paise: balance.abs(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SplitPrimaryButton(
                                label: settled ? 'Record payment' : 'Settle up',
                                height: 48,
                                onPressed: () =>
                                    _settle(context, person, balance),
                              ),
                            ),
                            if (owesYou) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: PressableScale(
                                  onTap: () => _remind(person, balance),
                                  child: Container(
                                    key: const Key('split-remind'),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(48),
                                      color: ArthamColors.glass,
                                      border: Border.all(color: ArthamColors.line),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.ios_share_rounded, size: 18, color: ArthamColors.text),
                                        SizedBox(width: 8),
                                        Text(
                                          'Remind',
                                          style: TextStyle(
                                            color: ArthamColors.text,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'HISTORY',
                  style: TextStyle(
                    color: ArthamColors.lavender,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing here yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ArthamColors.muted),
                    ),
                  ),
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppearIn(
                      index: i + 1,
                      child: Dismissible(
                        key: ValueKey(entries[i].id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDelete(context, entries[i]),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: ArthamColors.debitTint,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: ArthamColors.debit),
                        ),
                        child: _EntryTile(entry: entries[i]),
                      ),
                    ),
                  ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sumLine(entries, balance),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ArthamColors.faint,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _sumLine(List<SplitEntry> entries, int balance) {
    final parts = StringBuffer();
    for (final entry in entries.reversed) {
      final value = splitMoney(entry.amountPaise);
      if (parts.isEmpty) {
        parts.write(entry.signedPaise < 0 ? '−$value' : value);
      } else {
        parts.write(entry.signedPaise < 0 ? ' − $value' : ' + $value');
      }
    }
    if (entries.length > 6) return 'Net ${splitMoney(balance.abs())}';
    final tail = balance == 0
        ? 'all square'
        : balance > 0
        ? '${splitMoney(balance)} still owed to you'
        : '${splitMoney(-balance)} still owed by you';
    return '$parts = $tail';
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final SplitEntry entry;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final positive = entry.signedPaise > 0;
    final settlement = entry.isSettlement;
    final date = '${entry.date.day} ${_months[entry.date.month - 1]}';
    final detail = switch (entry.kind) {
      SplitEntryKind.lent =>
        'you paid ${splitMoney(entry.billPaise ?? entry.amountPaise)}',
      SplitEntryKind.borrowed => 'they paid, your share',
      SplitEntryKind.received => 'repayment received',
      SplitEntryKind.paidBack => 'repayment sent',
    };
    final color = settlement ? ArthamColors.lavender : ArthamColors.peach;
    return SplitPanel(
      radius: 18,
      tint: settlement ? ArthamColors.glassSoft : ArthamColors.glass,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              settlement ? Icons.swap_horiz_rounded : Icons.receipt_long_outlined,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ArthamColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$date · $detail',
                  style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : '−'}${splitMoney(entry.amountPaise)}',
            style: TextStyle(
              color: positive ? ArthamColors.mint : ArthamColors.debit,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
