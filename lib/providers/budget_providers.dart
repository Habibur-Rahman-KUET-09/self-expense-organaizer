import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'database_providers.dart';

typedef MonthKey = ({int year, int month});
typedef CategoryMonthKey = ({int categoryId, int year, int month});

/// All budgets for a given month (FR-2), reactive to edits.
final budgetsForMonthProvider = StreamProvider.autoDispose
    .family<List<Budget>, MonthKey>((ref, key) {
      return ref.watch(budgetRepositoryProvider).watchForMonth(key.year, key.month);
    });

/// A single category's budget for a given month, or null if unset.
final budgetForCategoryMonthProvider = StreamProvider.autoDispose
    .family<Budget?, CategoryMonthKey>((ref, key) {
      return ref
          .watch(budgetRepositoryProvider)
          .watchForCategoryMonth(key.categoryId, key.year, key.month);
    });

/// FR-2.3: auto-calculated total monthly min/max across all categories.
final monthlyBudgetTotalsProvider = FutureProvider.autoDispose
    .family<({double min, double max}), MonthKey>((ref, key) {
      return ref.watch(budgetRepositoryProvider).totalsForMonth(key.year, key.month);
    });
