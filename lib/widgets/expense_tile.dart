import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../providers/database_providers.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);
final _dateFormat = DateFormat.yMMMd();

/// One expense with Edit/Delete in its menu — on the Add Expense screen's
/// recent list and on the All entries screen.
class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({
    super.key,
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
