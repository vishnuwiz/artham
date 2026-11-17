import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/split/split_models.dart';
import '../../data/split/split_repository.dart';
import '../../theme/artham_theme.dart';
import '../../widgets/micro_interactions.dart';
import 'split_shared.dart';

/// Records a bill and divides it between you and the people you shared it
/// with. Either you paid (they owe you) or someone else did (you owe them).
class AddSplitScreen extends StatefulWidget {
  const AddSplitScreen({
    super.key,
    required this.repository,
    required this.database,
    this.initialPersonId,
  });

  final SplitRepository repository;
  final AppDatabase database;
  final String? initialPersonId;

  @override
  State<AddSplitScreen> createState() => _AddSplitScreenState();
}

class _AddSplitScreenState extends State<AddSplitScreen> {
  final _total = TextEditingController();
  final _title = TextEditingController();
  final _values = <String, TextEditingController>{}; // key: person id or 'me'

  List<BankAccount> _accounts = const [];
  List<Category> _categories = const [];
  int? _accountId;
  int? _categoryId;
  DateTime _date = DateTime.now();

  bool _iPaid = true;
  String? _payerId; // when someone else paid
  final List<String> _selected = []; // people ids, in tap order
  SplitMode _mode = SplitMode.equal;
  bool _saving = false;
  String? _error;

  SplitRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    final first = widget.initialPersonId;
    if (first != null) _selected.add(first);
    _repo.load();
    _loadLists();
  }

  @override
  void dispose() {
    _total.dispose();
    _title.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    final transactions = TransactionRepository(widget.database);
    final accounts = await transactions.getActiveAccounts();
    final categories = await transactions.getCategories('expense');
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _categories = categories;
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    });
  }

  TextEditingController _controller(String key) =>
      _values.putIfAbsent(key, () => TextEditingController());

  int get _totalPaise => parseRupeesToPaise(_total.text) ?? 0;

  /// People at the table, you first.
  List<String> get _participants {
    if (_iPaid) return ['me', ..._selected];
    final payer = _payerId;
    return payer == null ? ['me'] : ['me', payer];
  }

  /// Each participant's share in paise, or null with [_shareProblem] set.
  String? _shareProblem;

  Map<String, int>? _computeShares() {
    _shareProblem = null;
    final total = _totalPaise;
    final people = _participants;
    if (total <= 0) return null;
    if (people.length < 2) {
      _shareProblem = _iPaid ? 'Pick someone to split with' : 'Pick who paid';
      return null;
    }
    switch (_mode) {
      case SplitMode.equal:
        final parts = splitEqually(total, people.length);
        return {for (var i = 0; i < people.length; i++) people[i]: parts[i]};
      case SplitMode.amounts:
        final map = <String, int>{};
        var sum = 0;
        for (final id in people) {
          final value = parseRupeesToPaise(_controller(id).text) ?? 0;
          map[id] = value;
          sum += value;
        }
        if (sum != total) {
          final diff = total - sum;
          _shareProblem = diff > 0
              ? '${splitMoney(diff)} left to assign'
              : '${splitMoney(-diff)} too much';
          return null;
        }
        return map;
      case SplitMode.percent:
        final percents = <double>[];
        for (final id in people) {
          final text = _controller(id).text.replaceAll('%', '').trim();
          percents.add(double.tryParse(text) ?? 0);
        }
        final sum = percents.fold<double>(0, (a, b) => a + b);
        if ((sum - 100).abs() > 0.001) {
          final diff = 100 - sum;
          _shareProblem = diff > 0
              ? '${_trim(diff)}% left to assign'
              : '${_trim(-diff)}% too much';
          return null;
        }
        final parts = splitByPercent(total, percents);
        return {for (var i = 0; i < people.length; i++) people[i]: parts[i]};
    }
  }

  String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Future<void> _addPerson() async {
    final name = await askPersonName(context);
    if (name == null || name.trim().isEmpty) return;
    final person = await _repo.addPerson(name);
    if (!mounted) return;
    setState(() {
      if (_iPaid) {
        if (!_selected.contains(person.id)) _selected.add(person.id);
      } else {
        _payerId = person.id;
      }
    });
  }

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
    final shares = _computeShares();
    if (_totalPaise <= 0) {
      setState(() => _error = 'Enter the total amount');
      return;
    }
    if (shares == null) {
      setState(() => _error = _shareProblem ?? 'Check the amounts');
      return;
    }
    final accountId = _accountId;
    if (_iPaid && accountId == null) {
      setState(() => _error = 'Add a bank account first');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_iPaid) {
        await _repo.addSplitExpense(
          title: _title.text,
          totalPaise: _totalPaise,
          accountId: accountId!,
          categoryId: _categoryId,
          date: _date,
          shares: [
            for (final entry in shares.entries)
              SplitShare(
                personId: entry.key == 'me' ? null : entry.key,
                paise: entry.value,
              ),
          ],
        );
      } else {
        final mine = shares['me'] ?? 0;
        if (mine <= 0) {
          throw ArgumentError('Your share is zero, so there is nothing to record');
        }
        await _repo.addOwedByYou(
          personId: _payerId!,
          amountPaise: mine,
          title: _title.text,
          date: _date,
        );
      }
      if (!mounted) return;
      await showSavedCheck(context);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ArgumentError
            ? '${error.message}'
            : 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _repo.ledger.value;
    final shares = _computeShares();
    final problem = _shareProblem;
    final categoryName = _categories
        .where((c) => c.id == _categoryId)
        .map((c) => c.name)
        .firstOrNull;
    final myShare = shares?['me'];

    return ArthamScaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Split an expense',
                          style: TextStyle(
                            color: ArthamColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppearIn(
                    child: SlidingSegmented(
                      labels: const ['I paid', 'Someone else paid'],
                      selectedIndex: _iPaid ? 0 : 1,
                      segmentWidth: 170,
                      height: 42,
                      onChanged: (index) => setState(() {
                        _iPaid = index == 0;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppearIn(
                    index: 1,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextField(
                            key: const Key('split-total'),
                            controller: _total,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _error = null),
                            style: const TextStyle(
                              color: ArthamColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: splitFieldDecoration('Total bill')
                                .copyWith(prefixText: '₹ '),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 5,
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(_categories.length),
                            initialValue: _categoryId,
                            isExpanded: true,
                            dropdownColor: ArthamColors.sheet,
                            style: const TextStyle(color: ArthamColors.text),
                            decoration: splitFieldDecoration('Category'),
                            items: [
                              for (final category in _categories)
                                DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (value) => setState(() => _categoryId = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppearIn(
                    index: 2,
                    child: TextField(
                      key: const Key('split-title'),
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: ArthamColors.text),
                      decoration: splitFieldDecoration('Description', hint: 'Team lunch'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppearIn(
                    index: 3,
                    child: Row(
                      children: [
                        if (_iPaid)
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(_accounts.length),
                              initialValue: _accountId,
                              isExpanded: true,
                              dropdownColor: ArthamColors.sheet,
                              style: const TextStyle(color: ArthamColors.text),
                              decoration: splitFieldDecoration('Paid from'),
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
                          ),
                        if (_iPaid) const SizedBox(width: 10),
                        Expanded(
                          child: PressableScale(
                            onTap: _pickDate,
                            child: GlassPanel(
                              radius: 15,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: ArthamColors.muted),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_date.day}/${_date.month}/${_date.year}',
                                    style: const TextStyle(
                                      color: ArthamColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel(_iPaid ? 'SPLIT WITH' : 'WHO PAID'),
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final person in ledger.people)
                          _PersonChip(
                            person: person,
                            selected: _iPaid
                                ? _selected.contains(person.id)
                                : _payerId == person.id,
                            onTap: () => setState(() {
                              _error = null;
                              if (_iPaid) {
                                _selected.contains(person.id)
                                    ? _selected.remove(person.id)
                                    : _selected.add(person.id);
                              } else {
                                _payerId = person.id;
                              }
                            }),
                          ),
                        _AddChip(onTap: _addPerson),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: _sectionLabel('SPLIT')),
                      for (final mode in SplitMode.values) ...[
                        const SizedBox(width: 6),
                        SplitChip(
                          label: switch (mode) {
                            SplitMode.equal => 'Equally',
                            SplitMode.amounts => 'Amounts',
                            SplitMode.percent => '%',
                          },
                          selected: _mode == mode,
                          onTap: () => setState(() {
                            _mode = mode;
                            _error = null;
                          }),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    padding: EdgeInsets.zero,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          for (final id in _participants)
                            _ShareRow(
                              key: ValueKey('row-$id-${_mode.name}'),
                              person: id == 'me' ? null : ledger.personById(id),
                              mode: _mode,
                              computedPaise: shares?[id],
                              controller: _mode == SplitMode.equal ? null : _controller(id),
                              onChanged: () => setState(() => _error = null),
                              isLast: id == _participants.last,
                            ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: (problem == null || _totalPaise <= 0)
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              problem,
                              style: const TextStyle(color: ArthamColors.peach, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: GlassPanel(
                      key: ValueKey('${shares != null}$myShare$_iPaid$categoryName'),
                      tint: ArthamColors.mintTint,
                      borderColor: const Color(0x4D8FE3C4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: ArthamColors.mint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _summary(shares, categoryName),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SplitPrimaryButton(
                label: 'Save expense',
                busy: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary(Map<String, int>? shares, String? categoryName) {
    if (shares == null) {
      return _iPaid
          ? 'Only your own share counts as your spending. The rest is '
                'recorded as owed to you.'
          : 'This only notes what you owe. No money leaves your accounts '
                'until you settle up.';
    }
    final mine = shares['me'] ?? 0;
    if (_iPaid) {
      final others = _totalPaise - mine;
      final label = categoryName == null ? 'spending' : '$categoryName spending';
      return 'Only ${splitMoney(mine)} counts as your $label. '
          '${splitMoney(others)} is recorded as owed to you.';
    }
    return 'You owe ${splitMoney(mine)}. This only notes it in your ledger; '
        'no money leaves your accounts until you settle up.';
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: ArthamColors.lavender,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    ),
  );
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final SplitPerson person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? ArthamColors.lavenderTint : ArthamColors.glass,
          border: Border.all(
            color: selected ? ArthamColors.lavender : ArthamColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: selected
                  ? Container(
                      key: const ValueKey('on'),
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: ArthamColors.lavender,
                      ),
                      child: const Icon(Icons.check_rounded, size: 16, color: ArthamColors.onAccent),
                    )
                  : SplitAvatar(
                      key: const ValueKey('off'),
                      person: person,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              person.name,
              style: TextStyle(
                color: ArthamColors.text,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        key: const Key('split-add-person-chip'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ArthamColors.line),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: ArthamColors.lavender),
            SizedBox(width: 6),
            Text(
              'Add person',
              style: TextStyle(
                color: ArthamColors.lavender,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    super.key,
    required this.person,
    required this.mode,
    required this.computedPaise,
    required this.controller,
    required this.onChanged,
    required this.isLast,
  });

  final SplitPerson? person;
  final SplitMode mode;
  final int? computedPaise;
  final TextEditingController? controller;
  final VoidCallback onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: ArthamColors.glassSoft)),
      ),
      child: Row(
        children: [
          SplitAvatar(person: person, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person?.name ?? 'You',
              style: const TextStyle(
                color: ArthamColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (mode == SplitMode.equal || controller == null)
            computedPaise == null
                ? const Text('—', style: TextStyle(color: ArthamColors.faint))
                : AnimatedMoney(
                    paise: computedPaise!,
                    style: const TextStyle(
                      color: ArthamColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  )
          else
            SizedBox(
              width: 96,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onChanged(),
                style: const TextStyle(
                  color: ArthamColors.text,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: const TextStyle(color: ArthamColors.faint),
                  suffixText: mode == SplitMode.percent ? '%' : null,
                  prefixText: mode == SplitMode.amounts ? '₹' : null,
                  border: InputBorder.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
