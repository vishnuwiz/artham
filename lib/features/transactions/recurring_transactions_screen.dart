import 'package:material_ui/material_ui.dart';

import '../../theme/artham_theme.dart';
import '../../theme/category_icons.dart';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;

import '../../data/app_database.dart';
import '../../data/recurring_pattern_detector.dart';
import '../../data/repositories/recurring_transaction_repository.dart';

const Color recurringGreen = ArthamColors.lavender;
const Color recurringNavy = ArthamColors.text;
const Color recurringBackground = Colors.transparent;

class RecurringTransactionsScreen extends StatefulWidget {
  final AppDatabase database;

  const RecurringTransactionsScreen({super.key, required this.database});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  late final RecurringTransactionRepository _repository;
  late Future<_RecurringScreenData> _screenData;

  @override
  void initState() {
    super.initState();
    _repository = RecurringTransactionRepository(widget.database);
    _loadSchedules();
  }

  void _loadSchedules() {
    _screenData = _fetchSchedules();
  }

  Future<_RecurringScreenData> _fetchSchedules() async {
    final schedules = await _repository.getSchedules();
    final dueSchedules = await _repository.getDueSchedules();
    final suggestions = await _repository.getPatternSuggestions();

    return _RecurringScreenData(
      schedules: schedules,
      dueScheduleIds: dueSchedules.map((item) => item.schedule.id).toSet(),
      suggestions: suggestions,
    );
  }

  Future<void> _refresh() async {
    setState(_loadSchedules);
    await _screenData;
  }

  Future<void> _addSchedule({RecurringPatternSuggestion? suggestion}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRecurringScheduleSheet(
        database: widget.database,
        repository: _repository,
        suggestion: suggestion,
      ),
    );

    if (created == true && mounted) {
      setState(_loadSchedules);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suggestion == null
                ? 'Recurring schedule created.'
                : 'Pattern reviewed and recurring schedule created.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmOccurrence(RecurringScheduleDetails item) async {
    final schedule = item.schedule;
    final amount = _formatAmount(schedule.amountPaise);
    final dueDate = _formatDate(schedule.nextDueDate);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm recurring transaction'),
        content: Text(
          'Record $amount as ${schedule.transactionType} for '
          '${item.category.name} on $dueDate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: recurringGreen),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final created = await _repository.confirmNextOccurrence(schedule.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'Recurring transaction recorded.'
                : 'This occurrence was already recorded or is no longer due.',
          ),
        ),
      );

      setState(_loadSchedules);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to record transaction: $e')),
      );
    }
  }

  Future<void> _toggleSchedule(RecurringScheduleDetails item) async {
    try {
      await _repository.setScheduleActive(
        scheduleId: item.schedule.id,
        isActive: !item.schedule.isActive,
      );
      if (!mounted) return;
      setState(_loadSchedules);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update schedule: $e')));
    }
  }

  Future<void> _deleteSchedule(RecurringScheduleDetails item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recurring schedule?'),
        content: const Text(
          'This removes the schedule only. Transactions already recorded '
          'will remain in your activity and account balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ArthamColors.debit),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _repository.deleteSchedule(item.schedule.id);
      if (!mounted) return;
      setState(_loadSchedules);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring schedule deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete schedule: $e')));
    }
  }

  String _formatAmount(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  String _frequencyLabel(RecurringSchedule schedule) {
    final unit = switch (schedule.frequency) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      'yearly' => 'year',
      _ => schedule.frequency,
    };

    if (schedule.interval == 1) {
      return 'Every $unit';
    }
    return 'Every ${schedule.interval} $unit${schedule.interval == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return ArthamScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: recurringNavy,
        elevation: 0,
        title: const Text(
          'Recurring Transactions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Add recurring schedule',
            onPressed: _addSchedule,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_RecurringScreenData>(
        future: _screenData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: recurringGreen),
            );
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          final data = snapshot.data!;
          if (data.schedules.isEmpty && data.suggestions.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            color: recurringGreen,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                _buildSummary(data),
                if (data.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _buildSuggestionSection(data.suggestions),
                ],
                const SizedBox(height: 22),
                if (data.schedules.isNotEmpty) ...[
                  const Text(
                    'YOUR SCHEDULES',
                    style: TextStyle(
                      color: ArthamColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...data.schedules.map(
                    (item) => _buildScheduleCard(
                      item,
                      isDue: data.dueScheduleIds.contains(item.schedule.id),
                    ),
                  ),
                ] else
                  _buildNoSchedulesNotice(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchedule,
        backgroundColor: recurringGreen,
        foregroundColor: ArthamColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New schedule'),
      ),
    );
  }

  Widget _buildSummary(_RecurringScreenData data) {
    final activeCount = data.schedules
        .where((item) => item.schedule.isActive)
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ArthamColors.heroGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryValue('Active schedules', activeCount.toString()),
          ),
          Container(width: 1, height: 42, color: Colors.white24),
          const SizedBox(width: 18),
          Expanded(
            child: _summaryValue(
              'Due to confirm',
              data.dueScheduleIds.length.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSuggestionSection(List<RecurringPatternSuggestion> suggestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POSSIBLE RECURRING PAYMENTS',
          style: TextStyle(
            color: ArthamColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Artham found patterns in your past transactions. Review each one '
          'before saving a schedule.',
          style: TextStyle(
            color: ArthamColors.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map(_buildSuggestionCard),
      ],
    );
  }

  Widget _buildSuggestionCard(RecurringPatternSuggestion suggestion) {
    final isIncome = suggestion.transactionType == 'income';
    final accent = isIncome ? recurringGreen : ArthamColors.debit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ArthamColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: recurringNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${suggestion.categoryName} · ${suggestion.accountLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(suggestion.amountPaise),
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _infoChip(_suggestionFrequencyLabel(suggestion)),
              _infoChip('${suggestion.occurrenceCount} payments found'),
              _infoChip('Last: ${_formatDate(suggestion.lastOccurrence)}'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Next expected: ${_formatDate(suggestion.nextExpectedDate)}. '
            'This is an estimate based on transaction history.',
            style: const TextStyle(
              color: ArthamColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _addSchedule(suggestion: suggestion),
              style: FilledButton.styleFrom(
                backgroundColor: recurringGreen,
                foregroundColor: ArthamColors.onAccent,
              ),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Review & set up'),
            ),
          ),
        ],
      ),
    );
  }

  String _suggestionFrequencyLabel(RecurringPatternSuggestion suggestion) {
    final unit = suggestion.frequency == 'weekly'
        ? 'week'
        : suggestion.frequency == 'yearly'
        ? 'year'
        : 'month';
    return suggestion.interval == 1
        ? 'Every $unit'
        : 'Every ${suggestion.interval} ${unit}s';
  }

  Widget _buildNoSchedulesNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ArthamColors.glassGradient,
        border: ArthamColors.glassBorder,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No schedules created yet. You can review a detected pattern above '
        'or create a schedule manually.',
        style: TextStyle(color: ArthamColors.muted, fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _buildScheduleCard(
    RecurringScheduleDetails item, {
    required bool isDue,
  }) {
    final schedule = item.schedule;
    final isIncome = schedule.transactionType == 'income';
    final accent = isIncome ? recurringGreen : ArthamColors.debit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDue
              ? recurringGreen.withValues(alpha: 0.45)
              : ArthamColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      style: const TextStyle(
                        color: recurringNavy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bankAccountDisplayLabel(
                        item.account.bankName,
                        item.account.accountNumberLast4,
                      ),
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(schedule.amountPaise),
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _infoChip(_frequencyLabel(schedule)),
              _infoChip('Next: ${_formatDate(schedule.nextDueDate)}'),
              _infoChip(schedule.isActive ? 'Active' : 'Paused'),
              if (isDue) _infoChip('Due now', color: recurringGreen),
            ],
          ),
          if ((schedule.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              schedule.description!,
              style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (isDue && schedule.isActive)
                Expanded(
                  child: FilledButton(
                    onPressed: () => _confirmOccurrence(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: recurringGreen,
                      foregroundColor: ArthamColors.onAccent,
                      minimumSize: const Size(0, 42),
                    ),
                    child: const Text('Confirm transaction'),
                  ),
                ),
              if (isDue && schedule.isActive) const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _toggleSchedule(item),
                style: OutlinedButton.styleFrom(
                  foregroundColor: recurringNavy,
                  minimumSize: const Size(0, 42),
                ),
                child: Text(schedule.isActive ? 'Pause' : 'Resume'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete schedule',
                onPressed: () => _deleteSchedule(item),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: ArthamColors.debit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? recurringNavy).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? recurringNavy,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: recurringGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.event_repeat_rounded,
                color: recurringGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No recurring transactions yet',
              style: TextStyle(
                color: recurringNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up regular income or expenses such as salary, rent, '
              'subscriptions or bills.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ArthamColors.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addSchedule,
              style: FilledButton.styleFrom(
                backgroundColor: recurringGreen,
                foregroundColor: ArthamColors.onAccent,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create first schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: ArthamColors.debit,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load recurring schedules.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ArthamColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => setState(_loadSchedules),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringScreenData {
  final List<RecurringScheduleDetails> schedules;
  final Set<int> dueScheduleIds;
  final List<RecurringPatternSuggestion> suggestions;

  const _RecurringScreenData({
    required this.schedules,
    required this.dueScheduleIds,
    required this.suggestions,
  });
}

class _AddRecurringScheduleSheet extends StatefulWidget {
  final AppDatabase database;
  final RecurringTransactionRepository repository;
  final RecurringPatternSuggestion? suggestion;

  const _AddRecurringScheduleSheet({
    required this.database,
    required this.repository,
    this.suggestion,
  });

  @override
  State<_AddRecurringScheduleSheet> createState() =>
      _AddRecurringScheduleSheetState();
}

class _AddRecurringScheduleSheetState
    extends State<_AddRecurringScheduleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _interval = 1;

  List<BankAccount> _accounts = [];
  List<Category> _categories = [];

  int? _accountId;
  int? _categoryId;
  String _transactionType = 'expense';
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    if (suggestion != null) {
      _transactionType = suggestion.transactionType;
      _frequency = suggestion.frequency;
      _interval = suggestion.interval;
      _startDate = suggestion.nextExpectedDate;
    }
    _loadFormData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final accounts =
          await (widget.database.select(widget.database.bankAccounts)
                ..where((a) => a.isActive.equals(true))
                ..orderBy([(a) => OrderingTerm.asc(a.bankName)]))
              .get();

      final categoryRows =
          await (widget.database.select(widget.database.categories)
                ..where(
                  (category) =>
                      category.type.equals(_transactionType) &
                      category.isArchived.equals(false),
                )
                ..orderBy([(category) => OrderingTerm.asc(category.name)]))
              .get();

      if (!mounted) return;
      final suggestion = widget.suggestion;
      final suggestedAccountId = suggestion?.accountId;
      final suggestedCategoryId = suggestion?.categoryId;
      setState(() {
        _accounts = accounts;
        _categories = categoryRows;
        _accountId = accounts.any((item) => item.id == suggestedAccountId)
            ? suggestedAccountId
            : (accounts.isEmpty ? null : accounts.first.id);
        _categoryId = categoryRows.any((item) => item.id == suggestedCategoryId)
            ? suggestedCategoryId
            : (categoryRows.isEmpty ? null : categoryRows.first.id);
        _isLoading = false;
      });
      if (suggestion != null) {
        _amountController.text = (suggestion.amountPaise / 100).toStringAsFixed(
          2,
        );
        _descriptionController.text = suggestion.description;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load form: $e')));
    }
  }

  Future<void> _changeType(String type) async {
    setState(() {
      _transactionType = type;
      _categoryId = null;
      _categories = [];
      _isLoading = true;
    });

    try {
      final categories =
          await (widget.database.select(widget.database.categories)
                ..where(
                  (category) =>
                      category.type.equals(type) &
                      category.isArchived.equals(false),
                )
                ..orderBy([(category) => OrderingTerm.asc(category.name)]))
              .get();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId = categories.isEmpty ? null : categories.first.id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load categories: $e')));
    }
  }

  Future<void> _pickDate({required bool isEndDate}) async {
    final initial = isEndDate ? (_endDate ?? _startDate) : _startDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;
    setState(() {
      if (isEndDate) {
        _endDate = selected;
      } else {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = null;
        }
      }
    });
  }

  String _frequencyUnit(int value) {
    final unit = _frequency == 'daily'
        ? 'day'
        : _frequency == 'weekly'
        ? 'week'
        : _frequency == 'yearly'
        ? 'year'
        : 'month';
    return value == 1 ? unit : '${unit}s';
  }

  Future<void> _pickRepeatInterval() async {
    var selectedInterval = _interval;
    final controller = FixedExtentScrollController(initialItem: _interval - 1);

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: ArthamColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Repeat every',
                          style: TextStyle(
                            color: recurringNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, selectedInterval),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: recurringGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: controller,
                    itemExtent: 44,
                    magnification: 1.12,
                    useMagnifier: true,
                    onSelectedItemChanged: (index) {
                      selectedInterval = index + 1;
                    },
                    children: List<Widget>.generate(
                      999,
                      (index) => Center(
                        child: Text(
                          '${index + 1} ${_frequencyUnit(index + 1)}',
                          style: const TextStyle(
                            color: recurringNavy,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
    if (result != null && mounted) {
      setState(() => _interval = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountId == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account and category.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    final interval = _interval;

    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        interval < 1 ||
        interval > 999) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.repository.createSchedule(
        accountId: _accountId!,
        categoryId: _categoryId!,
        amountPaise: (amount * 100).round(),
        transactionType: _transactionType,
        frequency: _frequency,
        interval: interval,
        startDate: _startDate,
        endDate: _endDate,
        description: _descriptionController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create schedule: $e')));
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: ArthamColors.glass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: ArthamColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: ArthamColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: recurringGreen, width: 1.4),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: ArthamColors.glassSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.suggestion == null
                          ? 'New recurring schedule'
                          : 'Review detected pattern',
                      style: const TextStyle(
                        color: recurringNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(color: recurringGreen),
                      ),
                    )
                  : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final accent = _transactionType == 'income'
        ? ArthamColors.mint
        : ArthamColors.debit;

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          if (widget.suggestion != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: recurringGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'Found in ${widget.suggestion!.occurrenceCount} similar '
                'transactions. Check the amount, account, category and '
                'frequency. No schedule is created until you save.',
                style: const TextStyle(
                  color: recurringNavy,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'expense',
                label: Text('Expense'),
                icon: Icon(Icons.north_east_rounded),
              ),
              ButtonSegment(
                value: 'income',
                label: Text('Income'),
                icon: Icon(Icons.south_west_rounded),
              ),
            ],
            selected: {_transactionType},
            onSelectionChanged: (selection) => _changeType(selection.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: accent.withValues(alpha: 0.12),
              selectedForegroundColor: accent,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _decoration(
              'Amount',
              hint: '0.00',
            ).copyWith(prefixText: '₹ '),
            validator: (value) {
              final amount = double.tryParse((value ?? '').trim());
              if (amount == null || !amount.isFinite || amount <= 0) {
                return 'Enter a valid amount';
              }
              if ((amount * 100).round() <= 0) {
                return 'Amount must be at least ₹0.01';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _accountId,
            isExpanded: true,
            decoration: _decoration('Bank account'),
            items: _accounts
                .map(
                  (account) => DropdownMenuItem<int>(
                    value: account.id,
                    child: Text(
                      bankAccountDisplayLabel(
                        account.bankName,
                        account.accountNumberLast4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _accountId = value),
            validator: (value) =>
                value == null ? 'Select a bank account' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: _decoration('Category'),
            items: _categories
                .map(
                  (category) => DropdownMenuItem<int>(
                    value: category.id,
                    child: CategoryLabel(category: category),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
            validator: (value) => value == null ? 'Select a category' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: _decoration('Repeat'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _frequency = value);
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickRepeatInterval,
            child: InputDecorator(
              decoration: _decoration('Repeat every').copyWith(
                suffixIcon: const Icon(
                  Icons.unfold_more_rounded,
                  color: recurringGreen,
                ),
                helperText:
                    'Repeats every $_interval ${_frequencyUnit(_interval)}',
              ),
              child: Row(
                children: [
                  Text(
                    '$_interval',
                    style: const TextStyle(
                      color: recurringNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Tap to change',
                    style: TextStyle(color: ArthamColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _dateTile(
            label: 'Start date',
            value: _formatDate(_startDate),
            onTap: () => _pickDate(isEndDate: false),
          ),
          const SizedBox(height: 10),
          _dateTile(
            label: 'End date (optional)',
            value: _endDate == null ? 'No end date' : _formatDate(_endDate!),
            onTap: () => _pickDate(isEndDate: true),
            trailing: _endDate == null
                ? null
                : IconButton(
                    onPressed: () => setState(() => _endDate = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            maxLength: 150,
            decoration: _decoration(
              'Description (optional)',
              hint: 'e.g. Monthly house rent',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: recurringGreen,
                foregroundColor: ArthamColors.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: ArthamColors.onAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save schedule',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: InputDecorator(
        decoration: _decoration(label).copyWith(
          suffixIcon: trailing ?? const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}
