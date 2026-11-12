import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/category_catalog.dart';
import '../../data/repositories/category_repository.dart';
import '../../theme/artham_theme.dart';
import '../../theme/category_icons.dart';

/// Settings > Categories: add, edit, hide and restore categories.
class CategoriesScreen extends StatefulWidget {
  final AppDatabase database;

  const CategoriesScreen({super.key, required this.database});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoryRepository _repository = CategoryRepository(
    widget.database,
  );

  String _type = 'expense';
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(seed: true);
  }

  Future<void> _load({bool seed = false}) async {
    try {
      if (seed) await _repository.ensureDefaultCategories();
      final categories = await _repository.getCategories(
        _type,
        includeArchived: true,
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load categories: $error';
      });
    }
  }

  void _changeType(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _isLoading = true;
    });
    _load();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor({Category? category}) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryEditorSheet(
        repository: _repository,
        type: category?.type ?? _type,
        category: category,
      ),
    );
    if (saved != null) {
      await _load();
      _showMessage(saved);
    }
  }

  Future<void> _delete(Category category) async {
    final transactions = await _repository.countTransactions(category.id);
    final inUse = await _repository.countUsage(category.id) > 0;
    if (!mounted) return;

    final willHide = inUse || category.seedKey != null;
    final String message;
    if (transactions > 0) {
      message =
          '${category.name} is used by $transactions '
          '${transactions == 1 ? 'transaction' : 'transactions'}. It will be '
          'hidden from new entries, and existing records keep this category. '
          'You can restore it later.';
    } else if (willHide) {
      message =
          '${category.name} will be hidden from new entries. '
          'You can restore it later.';
    } else {
      message = '${category.name} will be deleted.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArthamColors.sheet,
        title: Text(willHide ? 'Hide category?' : 'Delete category?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: ArthamColors.debit,
              foregroundColor: ArthamColors.onAccent,
            ),
            child: Text(willHide ? 'Hide' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _repository.deleteCategory(category.id);
      await _load();
      _showMessage(
        result == CategoryDeleteResult.deleted
            ? '${category.name} deleted.'
            : '${category.name} hidden.',
      );
    } on CategoryValidationException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Unable to remove the category: $error');
    }
  }

  Future<void> _restore(Category category) async {
    try {
      await _repository.restoreCategory(category.id);
      await _load();
      _showMessage('${category.name} restored.');
    } on CategoryValidationException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Unable to restore the category: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _categories.where((item) => !item.isArchived).toList();
    final hidden = _categories.where((item) => item.isArchived).toList();

    return ArthamScaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            color: ArthamColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _openEditor(),
        backgroundColor: ArthamColors.lavender,
        foregroundColor: ArthamColors.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
        children: [
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
            selected: {_type},
            onSelectionChanged: (selection) => _changeType(selection.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: ArthamColors.lavenderTint,
              selectedForegroundColor: ArthamColors.lavender,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: ArthamColors.lavender),
              ),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: ArthamColors.debit))
          else ...[
            Text(
              '${visible.length} ${_type == 'expense' ? 'expense' : 'income'} '
              '${visible.length == 1 ? 'category' : 'categories'}',
              style: const TextStyle(
                color: ArthamColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _CategoryGroup(
              children: [
                for (final category in visible)
                  _CategoryTile(
                    category: category,
                    onTap: () => _openEditor(category: category),
                    trailing: IconButton(
                      tooltip: 'Remove ${category.name}',
                      onPressed: () => _delete(category),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: ArthamColors.faint,
                      ),
                    ),
                  ),
              ],
            ),
            if (hidden.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Hidden',
                style: TextStyle(
                  color: ArthamColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Not offered for new entries. Existing records keep them.',
                style: TextStyle(color: ArthamColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _CategoryGroup(
                children: [
                  for (final category in hidden)
                    _CategoryTile(
                      category: category,
                      dimmed: true,
                      onTap: () => _openEditor(category: category),
                      trailing: TextButton(
                        onPressed: () => _restore(category),
                        child: const Text('Restore'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final List<Widget> children;

  const _CategoryGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ArthamColors.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ArthamColors.line),
      ),
      // A transparent Material so list-tile tap ripples show on the glass.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, indent: 64, color: ArthamColors.line),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final Widget trailing;
  final bool dimmed;

  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.trailing,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
        leading: CategoryIconBadge.forCategory(category, size: 38),
        title: Text(
          category.name,
          style: const TextStyle(
            color: ArthamColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}

/// Bottom sheet for creating or editing a category. Pops with a message for
/// a snackbar when saved.
class CategoryEditorSheet extends StatefulWidget {
  final CategoryRepository repository;
  final String type;
  final Category? category;

  const CategoryEditorSheet({
    super.key,
    required this.repository,
    required this.type,
    this.category,
  });

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late String _iconKey = categoryIcons.containsKey(widget.category?.iconKey)
      ? widget.category!.iconKey!
      : fallbackCategoryIconKey;
  late String _colorHex =
      widget.category?.colorHex ?? categoryColorPalette.first;
  String? _error;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final name = _nameController.text;
      if (_isEditing) {
        await widget.repository.updateCategory(
          id: widget.category!.id,
          name: name,
          iconKey: _iconKey,
          colorHex: _colorHex,
        );
      } else {
        await widget.repository.createCategory(
          name: name,
          type: widget.type,
          iconKey: _iconKey,
          colorHex: _colorHex,
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _isEditing ? 'Category updated.' : 'Category added.',
      );
    } on CategoryValidationException catch (error) {
      setState(() {
        _error = error.message;
        _isSaving = false;
      });
    } catch (error) {
      setState(() {
        _error = 'Unable to save: $error';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final color = categoryColorFor(_colorHex);
    final typeLabel = widget.type == 'income' ? 'income' : 'expense';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: ArthamColors.sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit category' : 'New $typeLabel category',
                      style: const TextStyle(
                        color: ArthamColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ArthamColors.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  Row(
                    children: [
                      CategoryIconBadge(
                        iconKey: _iconKey,
                        colorHex: _colorHex,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          key: const Key('category-name-field'),
                          controller: _nameController,
                          autofocus: !_isEditing,
                          maxLength: CategoryRepository.maxNameLength,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            errorText: _error,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SheetLabel('Colour'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final hex in categoryColorPalette)
                        _ColorDot(
                          color: categoryColorFor(hex),
                          selected:
                              hex.toUpperCase() == _colorHex.toUpperCase(),
                          onTap: () => setState(() => _colorHex = hex),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _SheetLabel('Icon'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final entry in categoryIcons.entries)
                        _IconChoice(
                          icon: entry.value,
                          color: color,
                          selected: entry.key == _iconKey,
                          onTap: () => setState(() => _iconKey = entry.key),
                        ),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 14),
                    Text(
                      'This is an $typeLabel category. To use it for the '
                      'other type, create a new category.',
                      style: const TextStyle(
                        color: ArthamColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: ArthamColors.lavender,
                      foregroundColor: ArthamColors.onAccent,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(_isEditing ? 'Save changes' : 'Add category'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ArthamColors.text,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ArthamColors.text : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: ArthamColors.onAccent,
                )
              : null,
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.2)
                : ArthamColors.glassSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : ArthamColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? color : ArthamColors.muted,
          ),
        ),
      ),
    );
  }
}
