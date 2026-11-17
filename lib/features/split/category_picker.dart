import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/app_database.dart';
import '../../data/repositories/category_repository.dart';
import '../../theme/artham_theme.dart';
import '../../theme/category_icons.dart';
import '../../widgets/micro_interactions.dart';
import 'split_shared.dart';

/// The tappable field that shows the chosen category and opens the picker.
class CategoryPickerField extends StatelessWidget {
  const CategoryPickerField({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final Category? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = selected;
    return PressableScale(
      onTap: onTap,
      child: SplitPanel(
        radius: 15,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: category == null
                  ? Container(
                      key: const ValueKey('none'),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ArthamColors.line),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: ArthamColors.muted,
                      ),
                    )
                  : CategoryIconBadge.forCategory(
                      category,
                      key: ValueKey(category.id),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(color: ArthamColors.muted, fontSize: 11),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      category?.name ?? 'Choose a category',
                      key: ValueKey(category?.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: category == null
                            ? ArthamColors.faint
                            : ArthamColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: ArthamColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Opens the "Select Category" sheet. Returns the chosen category, or null
/// when cancelled. [onCreated] runs after a new category is added so the
/// caller can reload its list.
Future<Category?> showCategoryPicker(
  BuildContext context, {
  required AppDatabase database,
  required List<Category> categories,
  required int? selectedId,
  required Future<List<Category>> Function() reload,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArthamColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (context) => _CategorySheet(
      database: database,
      initial: categories,
      selectedId: selectedId,
      reload: reload,
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.database,
    required this.initial,
    required this.selectedId,
    required this.reload,
  });

  final AppDatabase database;
  final List<Category> initial;
  final int? selectedId;
  final Future<List<Category>> Function() reload;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _search = TextEditingController();
  late List<Category> _categories = widget.initial;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createNew() async {
    final name = await askPersonNameLike(
      context,
      title: 'New category',
      hint: 'Category name',
      action: 'Add category',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await CategoryRepository(widget.database).createCategory(
        name: name,
        type: 'expense',
        iconKey: fallbackCategoryIconKey,
        colorHex: '#B9A5F5',
      );
      final fresh = await widget.reload();
      if (!mounted) return;
      final created = fresh.where((c) => c.id == id).firstOrNull;
      if (created != null) {
        Navigator.pop(context, created);
      } else {
        setState(() => _categories = fresh);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final shown = _categories
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query))
        .toList();
    final height = MediaQuery.of(context).size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ArthamColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: ArthamColors.debit,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Select Category',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ArthamColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('split-new-category'),
                    onPressed: _createNew,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                key: const Key('split-category-search'),
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: ArthamColors.text),
                decoration: InputDecoration(
                  hintText: 'Search category...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: ArthamColors.glass,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: ArthamColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: ArthamColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: ArthamColors.lavender,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        'No category found',
                        style: TextStyle(color: ArthamColors.muted),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 14,
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            AppearIn(
                              index: i ~/ 3,
                              offset: 10,
                              child: _CategoryChip(
                                category: shown[i],
                                selected: shown[i].id == widget.selectedId,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context, shown[i]);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFor(category.colorHex);
    return PressableScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? color.withValues(alpha: 0.22)
              : ArthamColors.ink.withValues(alpha: 0.35),
          border: Border.all(
            color: color.withValues(alpha: selected ? 1 : 0.75),
            width: selected ? 2 : 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIconFor(category.iconKey), size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: TextStyle(
                color: selected ? color : ArthamColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
