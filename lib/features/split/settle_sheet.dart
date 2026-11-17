import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/split/split_models.dart';
import '../../data/split/split_repository.dart';
import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import 'split_shared.dart';

/// Opens the settle-up sheet. Returns true when a repayment was recorded.
Future<bool?> showSettleSheet(
  BuildContext context, {
  required SplitRepository repository,
  required AppDatabase database,
  required SplitPerson person,
  required int balancePaise,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArthamColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => _SettleSheet(
      repository: repository,
      database: database,
      person: person,
      balancePaise: balancePaise,
    ),
  );
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({
    required this.repository,
    required this.database,
    required this.person,
    required this.balancePaise,
  });

  final SplitRepository repository;
  final AppDatabase database;
  final SplitPerson person;
  final int balancePaise;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  late bool _received = widget.balancePaise >= 0;
  final _amount = TextEditingController();
  List<BankAccount> _accounts = const [];
  int? _accountId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;
  int _chip = -1; // 0 full, 1 half, 2 other

  int get _outstanding => widget.balancePaise.abs();

  @override
  void initState() {
    super.initState();
    if (_outstanding > 0) _pick(0);
    _loadAccounts();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await TransactionRepository(
      widget.database,
    ).getActiveAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    });
  }

  void _pick(int chip) {
    setState(() {
      _chip = chip;
      _error = null;
      if (chip == 0) _amount.text = _plain(_outstanding);
      if (chip == 1) _amount.text = _plain(_outstanding ~/ 2);
      if (chip == 2) _amount.clear();
    });
  }

  String _plain(int paise) =>
      paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final paise = parseRupeesToPaise(_amount.text);
    if (paise == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    final accountId = _accountId;
    if (accountId == null) {
      setState(() => _error = 'Add a bank account first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.settle(
        personId: widget.person.id,
        amountPaise: paise,
        receivedFromThem: _received,
        accountId: accountId,
        date: _date,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.person.name;
    final paise = parseRupeesToPaise(_amount.text);
    final shown = paise == null ? 'the amount' : splitMoney(paise);
    final remaining = paise == null
        ? null
        : (widget.balancePaise + (_received ? -paise : paise));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ArthamColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SplitAvatar(person: widget.person, size: 48),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settle up with',
                      style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: ArthamColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SlidingSegmented(
              labels: ['$name paid me', 'I paid $name'],
              selectedIndex: _received ? 0 : 1,
              segmentWidth: 160,
              height: 42,
              onChanged: (index) => setState(() => _received = index == 0),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('split-settle-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {
                _chip = 2;
                _error = null;
              }),
              style: const TextStyle(
                color: ArthamColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
              decoration: splitFieldDecoration(
                _received ? 'Amount received' : 'Amount paid',
              ).copyWith(prefixText: '₹ '),
            ),
            if (_outstanding > 0) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  SplitChip(
                    label: 'Full ${splitMoney(_outstanding)}',
                    selected: _chip == 0,
                    onTap: () => _pick(0),
                  ),
                  if (_outstanding ~/ 2 > 0)
                    SplitChip(
                      label: 'Half ${splitMoney(_outstanding ~/ 2)}',
                      selected: _chip == 1,
                      onTap: () => _pick(1),
                    ),
                  SplitChip(
                    label: 'Other',
                    selected: _chip == 2,
                    onTap: () => _pick(2),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey(_accounts.length),
              initialValue: _accountId,
              dropdownColor: ArthamColors.sheet,
              style: const TextStyle(color: ArthamColors.text),
              decoration: splitFieldDecoration(
                _received ? 'Received into' : 'Paid from',
              ),
              items: [
                for (final account in _accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      bankAccountDisplayLabel(
                        account.bankName,
                        account.accountNumberLast4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 12),
            PressableScale(
              onTap: _pickDate,
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 15,
                child: Row(
                  children: [
                    const Text('Date', style: TextStyle(color: ArthamColors.muted, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: const TextStyle(
                        color: ArthamColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: GlassPanel(
                key: ValueKey('$_received$shown$remaining'),
                tint: ArthamColors.mintTint,
                borderColor: const Color(0x4D8FE3C4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: ArthamColors.mint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _received
                            ? 'This adds $shown to your account'
                                  '${remaining == 0 ? " and clears $name's balance" : ""}. '
                                  'It is not income and does not change any budget.'
                            : 'This takes $shown from your account'
                                  '${remaining == 0 ? " and clears your balance with $name" : ""}. '
                                  'It is not spending and does not change any budget.',
                        style: const TextStyle(
                          color: Color(0xFFE8F7F0),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: ArthamColors.debit, fontSize: 13),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SplitPrimaryButton(
              label: 'Mark as settled',
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
