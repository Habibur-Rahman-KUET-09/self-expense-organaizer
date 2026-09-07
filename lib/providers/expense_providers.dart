import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

/// Most recent expenses across all categories (FR-5.3's edit/delete entry
/// point), reactive to adds/edits/deletes.
final recentExpensesProvider = StreamProvider.autoDispose<List<Expense>>((
  ref,
) {
  return ref.watch(expenseRepositoryProvider).watchRecent();
});
