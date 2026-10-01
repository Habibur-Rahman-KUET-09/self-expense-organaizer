import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../providers/category_providers.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_tile.dart';
import 'add_expense_screen.dart';

final _money = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

/// Every expense, newest first and grouped by month, with search; each can
/// be edited (on its own page) or deleted. Back returns to Add Expense.
class AllExpensesScreen extends ConsumerStatefulWidget {
  const AllExpensesScreen({super.key});

  @override
  ConsumerState<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends ConsumerState<AllExpensesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(allExpensesProvider);
    final categories = {for (final c in ref.watch(allCategoriesProvider).value ?? const <Category>[]) c.id: c};

    String labelOf(Expense e) {
      final c = categories[e.categoryId];
      final parent = c?.parentId == null ? null : categories[c!.parentId!];
      return parent == null ? (c?.name ?? '') : '${parent.name} › ${c!.name}';
    }

    bool matches(Expense e) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (e.note ?? '').toLowerCase().contains(q) ||
          labelOf(e).toLowerCase().contains(q) ||
          e.amount.toStringAsFixed(0).contains(q);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All entries')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search note, category or amount',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              data: (all) {
                final shown = [for (final e in all) if (matches(e)) e];
                if (shown.isEmpty) {
                  return Center(child: Text(all.isEmpty ? 'No expenses logged yet.' : 'Nothing matches.'));
                }
                final items = _groupByMonth(shown);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    if (item is _MonthHeader) return _MonthHeaderTile(header: item);
                    final e = item as Expense;
                    final c = categories[e.categoryId];
                    return ExpenseTile(
                      expense: e,
                      category: c,
                      parentCategory: c?.parentId == null ? null : categories[c!.parentId!],
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => AddExpenseScreen(editing: e)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  /// Month headers (with that month's total) followed by its expenses.
  static List<Object> _groupByMonth(List<Expense> expenses) {
    final out = <Object>[];
    _MonthHeader? current;
    for (final e in expenses) {
      if (current == null || current.year != e.date.year || current.month != e.date.month) {
        current = _MonthHeader(e.date.year, e.date.month);
        out.add(current);
      }
      current.total += e.amount;
      current.count++;
      out.add(e);
    }
    return out;
  }
}

class _MonthHeader {
  _MonthHeader(this.year, this.month);

  final int year;
  final int month;
  double total = 0;
  int count = 0;
}

class _MonthHeaderTile extends StatelessWidget {
  const _MonthHeaderTile({required this.header});

  final _MonthHeader header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat.yMMMM().format(DateTime(header.year, header.month)),
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          Text('${header.count} · ${_money.format(header.total)}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
