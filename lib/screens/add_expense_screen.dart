import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../providers/category_providers.dart';
import '../providers/database_providers.dart';
import '../providers/expense_providers.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);
final _dateFormat = DateFormat.yMMMd();

/// FR-5: manual expense entry (amount, category/sub-category, date, note),
/// plus editing/deleting past entries (FR-5.3).
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _editingExpenseId;
  Category? _selectedTopCategory;
  Category? _selectedSubCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topCategoriesAsync = ref.watch(topLevelCategoriesProvider(true));

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingExpenseId == null ? 'Add Expense' : 'Edit Expense'),
        actions: [
          if (_editingExpenseId != null)
            TextButton(
              onPressed: () => setState(_resetForm),
              child: const Text('Cancel edit'),
            ),
        ],
      ),
      body: topCategoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No categories yet. Set up at least one category on the '
                  'Budget Setup screen before logging an expense.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildForm(context, categories);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Category> topCategories) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '$currencySymbol ',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              final parsed = double.tryParse(value.trim());
              if (parsed == null || parsed <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text('Category', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in topCategories)
                _CategoryChip(
                  category: category,
                  selected: _selectedTopCategory?.id == category.id,
                  onSelected: () => _selectTopCategory(category),
                ),
            ],
          ),
          if (_selectedTopCategory != null) ...[
            const SizedBox(height: 16),
            Text('Sub-category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final subsAsync = ref.watch(
                  subCategoriesProvider((
                    parentId: _selectedTopCategory!.id,
                    activeOnly: true,
                  )),
                );
                return subsAsync.when(
                  data: (subs) {
                    if (subs.isEmpty) {
                      return Text(
                        'No sub-categories under ${_selectedTopCategory!.name}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    // A sub-category is required once any exist for this
                    // category — see _selectTopCategory, which already made
                    // the user pick one before landing here. Tapping a chip
                    // only switches the pick; it can no longer be cleared.
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final sub in subs)
                          _CategoryChip(
                            category: sub,
                            selected: _selectedSubCategory?.id == sub.id,
                            onSelected: () => setState(() => _selectedSubCategory = sub),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 32),
                  error: (error, _) => Text('Error: $error'),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Date'),
            subtitle: Text(_dateFormat.format(_selectedDate)),
            trailing: const Icon(Icons.edit),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(_editingExpenseId == null ? 'Add Expense' : 'Save Changes'),
          ),
          const SizedBox(height: 32),
          Text('Recent Expenses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _RecentExpensesList(onEdit: _loadForEditing),
        ],
      ),
    );
  }

  /// A category with sub-categories can't take an expense directly — the
  /// user must pick one of its sub-categories first (via [_pickSubCategory]).
  /// A category with none behaves as before: selecting it is enough.
  Future<void> _selectTopCategory(Category category) async {
    final subs = await ref.read(
      subCategoriesProvider((parentId: category.id, activeOnly: true)).future,
    );
    if (!mounted) return;

    if (subs.isEmpty) {
      setState(() {
        _selectedTopCategory = category;
        _selectedSubCategory = null;
      });
      return;
    }

    final chosen = await _pickSubCategory(category, subs);
    if (chosen == null || !mounted) return; // cancelled: leave selection as-is
    setState(() {
      _selectedTopCategory = category;
      _selectedSubCategory = chosen;
    });
  }

  Future<Category?> _pickSubCategory(Category topCategory, List<Category> subs) {
    return showModalBottomSheet<Category>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Select a sub-category for ${topCategory.name}',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final sub in subs)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(sub.colorValue),
                  radius: 12,
                ),
                title: Text(sub.name),
                onTap: () => Navigator.of(sheetContext).pop(sub),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _loadForEditing(Expense expense) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final category = await categoryRepo.getById(expense.categoryId);
    if (category == null || !mounted) return;

    Category? top = category;
    Category? sub;
    if (category.parentId != null) {
      sub = category;
      top = await categoryRepo.getById(category.parentId!);
    }
    if (!mounted) return;

    setState(() {
      _editingExpenseId = expense.id;
      _selectedTopCategory = top;
      _selectedSubCategory = sub;
      _selectedDate = expense.date;
      _amountController.text = expense.amount == expense.amount.roundToDouble()
          ? expense.amount.toStringAsFixed(0)
          : expense.amount.toString();
      _noteController.text = expense.note ?? '';
    });
  }

  void _resetForm() {
    _editingExpenseId = null;
    _selectedTopCategory = null;
    _selectedSubCategory = null;
    _selectedDate = DateTime.now();
    _amountController.clear();
    _noteController.clear();
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    if (!formValid) return;
    if (_selectedTopCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a category')));
      return;
    }

    final categoryId = _selectedSubCategory?.id ?? _selectedTopCategory!.id;
    final amount = double.parse(_amountController.text.trim());
    final noteText = _noteController.text.trim();
    final repo = ref.read(expenseRepositoryProvider);

    if (_editingExpenseId == null) {
      await repo.add(
        ExpensesCompanion.insert(
          categoryId: categoryId,
          date: _selectedDate,
          amount: amount,
          note: Value(noteText.isEmpty ? null : noteText),
        ),
      );
    } else {
      final existing = await repo.getById(_editingExpenseId!);
      if (existing == null) return;
      await repo.update(
        existing.copyWith(
          categoryId: categoryId,
          date: _selectedDate,
          amount: amount,
          note: Value(noteText.isEmpty ? null : noteText),
        ),
      );
    }

    if (!mounted) return;
    final wasEditing = _editingExpenseId != null;
    setState(_resetForm);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(wasEditing ? 'Expense updated' : 'Expense added')),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final Category category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return ChoiceChip(
      label: Text(category.name),
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.25),
      onSelected: (_) => onSelected(),
    );
  }
}

class _RecentExpensesList extends ConsumerWidget {
  const _RecentExpensesList({required this.onEdit});

  final ValueChanged<Expense> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(recentExpensesProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No expenses logged yet.'),
          );
        }
        final categoriesById = {
          for (final c in categoriesAsync.value ?? const <Category>[]) c.id: c,
        };
        return Column(
          children: [
            for (final expense in expenses)
              _ExpenseTile(
                expense: expense,
                category: categoriesById[expense.categoryId],
                parentCategory: () {
                  final category = categoriesById[expense.categoryId];
                  if (category?.parentId == null) return null;
                  return categoriesById[category!.parentId!];
                }(),
                onEdit: () => onEdit(expense),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Error: $error'),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({
    required this.expense,
    required this.category,
    required this.parentCategory,
    required this.onEdit,
  });

  final Expense expense;
  final Category? category;
  // Set only when [category] is a sub-category, so the tile can show the
  // "Main category › Sub-category" hierarchy instead of a bare name that
  // could be mistaken for a top-level category.
  final Category? parentCategory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryLabel = parentCategory != null
        ? '${parentCategory!.name} › ${category?.name ?? 'Unknown'}'
        : (category?.name ?? 'Unknown category');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category != null ? Color(category!.colorValue) : Colors.grey,
          child: Text(
            (category?.name ?? '?').substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(_currencyFormat.format(expense.amount)),
        subtitle: Text(
          [
            categoryLabel,
            _dateFormat.format(expense.date),
            if ((expense.note ?? '').isNotEmpty) expense.note!,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handle(context, ref, action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'edit':
        onEdit();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete expense?'),
            content: const Text('This can\'t be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(expenseRepositoryProvider).delete(expense.id);
        }
    }
  }
}
