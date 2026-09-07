import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../logic/period_utils.dart';
import 'budget_providers.dart';
import 'database_providers.dart';

/// Most recent expenses across all categories (FR-5.3's edit/delete entry
/// point), reactive to adds/edits/deletes.
final recentExpensesProvider = StreamProvider.autoDispose<List<Expense>>((
  ref,
) {
  return ref.watch(expenseRepositoryProvider).watchRecent();
});

/// All expenses within a given month — used by the dashboard purely as a
/// reactive trigger (its emitted list isn't read directly) so aggregate
/// sums recompute whenever an expense in that month changes.
final expensesInMonthProvider = StreamProvider.autoDispose
    .family<List<Expense>, MonthKey>((ref, key) {
      final start = startOfMonth(key.year, key.month);
      final end = startOfNextMonth(key.year, key.month);
      return ref.watch(expenseRepositoryProvider).watchInRange(start, end);
    });
