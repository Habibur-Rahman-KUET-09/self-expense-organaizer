import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../services/budget_rollup_service.dart';
import 'database_providers.dart';
import 'service_providers.dart';

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
/// Superseded on-screen by [monthlyRollupTotalsProvider] (which folds
/// sub-category budgets into their parent) — kept for anything that wants
/// the raw, non-rolled-up sum.
final monthlyBudgetTotalsProvider = FutureProvider.autoDispose
    .family<({double min, double max}), MonthKey>((ref, key) {
      return ref.watch(budgetRepositoryProvider).totalsForMonth(key.year, key.month);
    });

/// A single category's *effective* budget for a month — its own budget, or
/// the sum of its sub-categories' budgets if any are set (see
/// BudgetRollupService). Reactive to any budget change that month
/// (covers editing a sub-category's budget while viewing its parent).
final effectiveBudgetForCategoryProvider = FutureProvider.autoDispose
    .family<EffectiveBudget, CategoryMonthKey>((ref, key) {
      ref.watch(budgetsForMonthProvider((year: key.year, month: key.month)));
      return ref
          .watch(budgetRollupServiceProvider)
          .effectiveBudgetForCategory(key.categoryId, key.year, key.month);
    });

/// The Budget Setup / Dashboard "Total Budget" figures, with sub-category
/// budgets rolled into their parent so nothing is counted twice.
final monthlyRollupTotalsProvider = FutureProvider.autoDispose
    .family<({double min, double max}), MonthKey>((ref, key) async {
      ref.watch(budgetsForMonthProvider(key));
      final rollup = ref.watch(budgetRollupServiceProvider);
      final min = await rollup.totalMinBudgetForMonth(key.year, key.month);
      final max = await rollup.totalCeilingBudgetForMonth(key.year, key.month);
      return (min: min, max: max);
    });
