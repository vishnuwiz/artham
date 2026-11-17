import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/split/split_models.dart';
import '../../data/split/split_repository.dart';
import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import 'add_split_screen.dart';
import 'person_ledger_screen.dart';
import 'split_shared.dart';

/// Everyone you share money with, grouped by who owes whom.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({
    super.key,
    required this.repository,
    required this.database,
  });

  final SplitRepository repository;
  final AppDatabase database;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  int _tab = 0; // 0 = owed to me, 1 = I owe
  bool _showSettled = false;

  SplitRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _repo.load();
  }

  Future<void> _addPerson() async {
    final name = await askPersonName(context);
    if (name == null || name.trim().isEmpty) return;
    await _repo.addPerson(name);
    HapticFeedback.lightImpact();
  }

  Future<void> _addExpense() async {
    await Navigator.push(
      context,
      splitRoute(
        (context) =>
            AddSplitScreen(repository: _repo, database: widget.database),
      ),
    );
    await _repo.load();
  }

  Future<void> _openPerson(SplitPerson person) async {
    await Navigator.push(
      context,
      splitRoute(
        (context) => PersonLedgerScreen(
          repository: _repo,
          database: widget.database,
          personId: person.id,
        ),
      ),
    );
    await _repo.load();
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AddExpenseButton(
        key: const Key('split-add-expense'),
        onTap: _addExpense,
      ),
      body: SafeArea(
        child: ValueListenableBuilder<SplitLedger>(
          valueListenable: _repo.ledger,
          builder: (context, ledger, _) {
            final owedMe = <SplitPerson>[];
            final iOwe = <SplitPerson>[];
            final settled = <SplitPerson>[];
            for (final person in ledger.people) {
              final balance = ledger.balanceFor(person.id);
              if (balance > 0) {
                owedMe.add(person);
              } else if (balance < 0) {
                iOwe.add(person);
              } else {
                settled.add(person);
              }
            }
            int sortByBalance(SplitPerson a, SplitPerson b) =>
                ledger.balanceFor(b.id).abs().compareTo(
                  ledger.balanceFor(a.id).abs(),
                );
            owedMe.sort(sortByBalance);
            iOwe.sort(sortByBalance);

            final list = _tab == 0 ? owedMe : iOwe;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'People',
                        style: TextStyle(
                          color: ArthamColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RoundIconButton(
                      key: const Key('split-add-person'),
                      icon: Icons.person_add_alt_1_rounded,
                      tooltip: 'Add person',
                      filled: true,
                      onTap: _addPerson,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppearIn(
                  child: SlidingSegmented(
                    labels: [
                      'Owed to me · ${splitMoney(ledger.totalOwedToYou)}',
                      'I owe · ${splitMoney(ledger.totalYouOwe)}',
                    ],
                    selectedIndex: _tab,
                    segmentWidth: 170,
                    height: 44,
                    onChanged: (index) => setState(() => _tab = index),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(_tab == 0 ? -0.04 : 0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_tab),
                    children: [
                      if (list.isEmpty)
                        _EmptyState(
                          hasPeople: ledger.people.isNotEmpty,
                          owedTab: _tab == 0,
                        )
                      else
                        for (var i = 0; i < list.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppearIn(
                              index: i,
                              child: _PersonRow(
                                person: list[i],
                                ledger: ledger,
                                onTap: () => _openPerson(list[i]),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                if (settled.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _SettledGroup(
                    people: settled,
                    ledger: ledger,
                    expanded: _showSettled,
                    onToggle: () =>
                        setState(() => _showSettled = !_showSettled),
                    onOpen: _openPerson,
                  ),
                ],
                const SizedBox(height: 18),
                const SplitPanel(
                  tint: ArthamColors.lavenderTint,
                  borderColor: Color(0x4DB9A5F5),
                  child: Text(
                    'People are only names stored on this phone. They never '
                    'receive anything from Artham and need no app.',
                    style: TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddExpenseButton extends StatelessWidget {
  const _AddExpenseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(54),
          gradient: const LinearGradient(
            colors: [Color(0xFFCDB8FF), Color(0xFFA78AEF)],
          ),
          boxShadow: [
            BoxShadow(
              color: ArthamColors.lavender.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: ArthamColors.onAccent),
            SizedBox(width: 8),
            Text(
              'Split an expense',
              style: TextStyle(
                color: ArthamColors.onAccent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.ledger,
    required this.onTap,
  });

  final SplitPerson person;
  final SplitLedger ledger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final balance = ledger.balanceFor(person.id);
    final count = ledger.entries
        .where((e) => e.personId == person.id && !e.isSettlement)
        .length;
    final owedToMe = balance > 0;
    return PressableScale(
      onTap: onTap,
      child: SplitPanel(
        child: Row(
          children: [
            SplitAvatar(person: person, size: 48, hero: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ArthamColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    count == 1 ? '1 shared expense' : '$count shared expenses',
                    style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedMoney(
                  paise: balance.abs(),
                  style: TextStyle(
                    color: owedToMe ? ArthamColors.mint : ArthamColors.debit,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  owedToMe ? 'owes you' : 'you owe',
                  style: const TextStyle(color: ArthamColors.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettledGroup extends StatelessWidget {
  const _SettledGroup({
    required this.people,
    required this.ledger,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  final List<SplitPerson> people;
  final SplitLedger ledger;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(SplitPerson) onOpen;

  @override
  Widget build(BuildContext context) {
    final names = people.map((p) => p.name).toList();
    final summary = names.length == 1
        ? '${names.first} is all square'
        : '${names.first} and ${names.length - 1} other'
              '${names.length - 1 == 1 ? '' : 's'} are all square';
    return Column(
      children: [
        PressableScale(
          onTap: onToggle,
          child: SplitPanel(
            tint: ArthamColors.glassSoft,
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: ArthamColors.mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settled people',
                        style: TextStyle(
                          color: ArthamColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        summary,
                        style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: const Icon(Icons.chevron_right_rounded, color: ArthamColors.faint),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  children: [
                    for (final person in people)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _PersonRow(
                          person: person,
                          ledger: ledger,
                          onTap: () => onOpen(person),
                        ),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasPeople, required this.owedTab});

  final bool hasPeople;
  final bool owedTab;

  @override
  Widget build(BuildContext context) {
    final message = !hasPeople
        ? 'No one yet. Split an expense and add the people you shared it with.'
        : owedTab
        ? 'Nobody owes you right now.'
        : 'You do not owe anyone right now.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            owedTab ? Icons.savings_outlined : Icons.thumb_up_alt_outlined,
            size: 40,
            color: ArthamColors.faint,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ArthamColors.muted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
