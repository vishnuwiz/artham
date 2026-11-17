import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/split/split_models.dart';
import '../../data/split/split_repository.dart';
import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import 'people_screen.dart';
import 'split_shared.dart';

/// Home card: what friends owe you, what you owe, and a way in.
class SharedMoneyCard extends StatelessWidget {
  const SharedMoneyCard({
    super.key,
    required this.repository,
    required this.database,
    required this.onChanged,
  });

  final SplitRepository repository;
  final AppDatabase database;

  /// Called after the user comes back, because balances may have changed.
  final VoidCallback onChanged;

  Future<void> _open(BuildContext context) async {
    await Navigator.push(
      context,
      splitRoute(
        (context) => PeopleScreen(repository: repository, database: database),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SplitLedger>(
      valueListenable: repository.ledger,
      builder: (context, ledger, _) {
        final owed = ledger.totalOwedToYou;
        final owe = ledger.totalYouOwe;
        final hasAny = ledger.people.isNotEmpty && ledger.entries.isNotEmpty;

        return PressableScale(
          onTap: () => _open(context),
          child: AnimatedSize(
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Container(
              key: const Key('home-shared-money-card'),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: ArthamColors.glassGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ArthamColors.lavender.withValues(alpha: 0.5)),
              ),
              child: hasAny ? _summary(ledger, owed, owe) : _invite(),
            ),
          ),
        );
      },
    );
  }

  Widget _invite() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: ArthamColors.lavenderTint,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.group_outlined, color: ArthamColors.lavender),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shared money',
                style: TextStyle(
                  color: ArthamColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Split a bill and track who owes you',
                style: TextStyle(color: ArthamColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: ArthamColors.lavender),
      ],
    );
  }

  Widget _summary(SplitLedger ledger, int owed, int owe) {
    final net = owed - owe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Shared money',
                style: TextStyle(
                  color: ArthamColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'People',
              style: TextStyle(
                color: ArthamColors.lavender,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: ArthamColors.lavender),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Tile(
                label: 'Owed to you',
                paise: owed,
                color: ArthamColors.mint,
                tint: ArthamColors.mintTint,
                caption: ledger.peopleWhoOweYou == 1
                    ? 'from 1 person'
                    : 'from ${ledger.peopleWhoOweYou} people',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Tile(
                label: 'You owe',
                paise: owe,
                color: ArthamColors.debit,
                tint: ArthamColors.debitTint,
                caption: ledger.peopleYouOwe == 1
                    ? 'to 1 person'
                    : 'to ${ledger.peopleYouOwe} people',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          net == 0
              ? 'All square'
              : net > 0
              ? 'Net: you are owed ${splitMoney(net)}'
              : 'Net: you owe ${splitMoney(-net)}',
          style: const TextStyle(
            color: ArthamColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.paise,
    required this.color,
    required this.tint,
    required this.caption,
  });

  final String label;
  final int paise;
  final Color color;
  final Color tint;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ArthamColors.muted, fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedMoney(
              paise: paise,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(color: ArthamColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}
