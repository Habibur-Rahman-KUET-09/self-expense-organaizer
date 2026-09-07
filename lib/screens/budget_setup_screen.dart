import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../models/enums.dart';
import '../providers/budget_providers.dart';
import '../providers/category_providers.dart';
import '../providers/database_providers.dart';
import '../widgets/budget_editor_sheet.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/month_selector.dart';
import 'add_expense_screen.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

/// FR-1/FR-2/FR-4: category & sub-category CRUD plus per-category monthly
/// min/max budgets and threshold settings.
class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  late DateTime _selectedMonth;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  MonthKey get _monthKey =>
      (year: _selectedMonth.year, month: _selectedMonth.month);

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(
      topLevelCategoriesProvider(!_showArchived),
    );
    final totalsAsync = ref.watch(monthlyBudgetTotalsProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Setup'),
        actions: [
          // Temporary direct link until Step 4c's Dashboard provides real
          // app-wide navigation between screens.
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Copy previous month\'s budgets forward',
            icon: const Icon(Icons.content_copy),
            onPressed: _copyFromPreviousMonth,
          ),
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(_showArchived ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          MonthSelector(
            year: _selectedMonth.year,
            month: _selectedMonth.month,
            onChanged: (dt) => setState(() => _selectedMonth = DateTime(dt.year, dt.month)),
          ),
          totalsAsync.when(
            data: (totals) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TotalStat(label: 'Total Min', value: totals.min),
                      _TotalStat(label: 'Total Max', value: totals.max),
                    ],
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox(height: 72),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const Center(
                    child: Text('No categories yet — tap + to add one.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: categories.length,
                  itemBuilder: (context, index) => _CategorySection(
                    category: categories[index],
                    monthKey: _monthKey,
                    showArchived: _showArchived,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context) async {
    final result = await CategoryFormDialog.show(context);
    if (result == null) return;
    await ref
        .read(categoryRepositoryProvider)
        .add(name: result.name, colorValue: result.colorValue);
  }

  Future<void> _copyFromPreviousMonth() async {
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(budgetRepositoryProvider)
        .copyForward(
          fromYear: prevMonth.year,
          fromMonth: prevMonth.month,
          toYear: _selectedMonth.year,
          toMonth: _selectedMonth.month,
        );
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied budgets from previous month')),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          _currencyFormat.format(value),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.category,
    required this.monthKey,
    required this.showArchived,
  });

  final Category category;
  final MonthKey monthKey;
  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subCategoriesAsync = ref.watch(
      subCategoriesProvider((parentId: category.id, activeOnly: !showArchived)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(backgroundColor: Color(category.colorValue)),
          title: Text(
            category.name,
            style: category.isActive
                ? null
                : const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          subtitle: _BudgetRow(categoryId: category.id, monthKey: monthKey),
          trailing: _CategoryMenu(category: category),
          children: [
            subCategoriesAsync.when(
              data: (subs) => Column(
                children: [
                  for (final sub in subs)
                    _SubCategoryTile(category: sub, monthKey: monthKey),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $error'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addSubCategory(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add sub-category'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSubCategory(BuildContext context, WidgetRef ref) async {
    final result = await CategoryFormDialog.show(context, isSubCategory: true);
    if (result == null) return;
    await ref
        .read(categoryRepositoryProvider)
        .add(name: result.name, parentId: category.id, colorValue: result.colorValue);
  }
}

class _SubCategoryTile extends ConsumerWidget {
  const _SubCategoryTile({required this.category, required this.monthKey});

  final Category category;
  final MonthKey monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 8),
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: Color(category.colorValue),
      ),
      title: Text(
        category.name,
        style: category.isActive
            ? null
            : const TextStyle(decoration: TextDecoration.lineThrough),
      ),
      subtitle: _BudgetRow(categoryId: category.id, monthKey: monthKey),
      trailing: _CategoryMenu(category: category),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.categoryId, required this.monthKey});

  final int categoryId;
  final MonthKey monthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(
      budgetForCategoryMonthProvider((
        categoryId: categoryId,
        year: monthKey.year,
        month: monthKey.month,
      )),
    );

    return budgetAsync.when(
      data: (budget) {
        if (budget == null) {
          return TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: () => _editBudget(context, ref, null),
            child: const Text('Set budget'),
          );
        }
        final baseLabel = budget.thresholdBase == ThresholdBase.min ? 'Min' : 'Max';
        return InkWell(
          onTap: () => _editBudget(context, ref, budget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${_currencyFormat.format(budget.minCost)} – '
              '${_currencyFormat.format(budget.maxCost)} '
              '· alert at ${budget.thresholdPercent.round()}% of $baseLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 16),
      error: (error, _) => Text('Error: $error'),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, Budget? existing) async {
    final category = await ref.read(categoryRepositoryProvider).getById(categoryId);
    if (category == null || !context.mounted) return;
    final result = await BudgetEditorSheet.show(
      context,
      existing: existing,
      categoryName: category.name,
    );
    if (result == null) return;
    await ref.read(budgetRepositoryProvider).upsert(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        year: monthKey.year,
        month: monthKey.month,
        minCost: Value(result.minCost),
        maxCost: result.maxCost,
        thresholdPercent: Value(result.thresholdPercent),
        thresholdBase: Value(result.thresholdBase),
      ),
    );
  }
}

class _CategoryMenu extends ConsumerWidget {
  const _CategoryMenu({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(
          value: 'toggle_active',
          child: Text(category.isActive ? 'Archive' : 'Unarchive'),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(categoryRepositoryProvider);
    switch (action) {
      case 'edit':
        final result = await CategoryFormDialog.show(
          context,
          existing: category,
          isSubCategory: category.parentId != null,
        );
        if (result == null) return;
        await repo.update(
          category.copyWith(name: result.name, colorValue: result.colorValue),
        );
      case 'toggle_active':
        await repo.setActive(category.id, !category.isActive);
      case 'delete':
        final messenger = ScaffoldMessenger.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete category?'),
            content: Text(
              'This permanently deletes "${category.name}". '
              'This can\'t be undone.',
            ),
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
        if (confirmed != true) return;
        try {
          await repo.delete(category.id);
        } on StateError catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
    }
  }
}
