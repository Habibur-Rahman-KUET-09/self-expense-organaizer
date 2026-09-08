import '../db/database.dart';
import '../logic/period_utils.dart';
import '../models/budget_extensions.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/expense_repository.dart';

/// A top-level category's effective budget for one month.
class EffectiveBudget {
  const EffectiveBudget({required this.min, required this.max, required this.fromSubCategories});

  final double min;
  final double? max;

  /// True when this was summed from sub-category budgets rather than the
  /// category's own budget row.
  final bool fromSubCategories;

  double get ceiling => max ?? min;
  bool get hasBudget => min > 0 || max != null;
}

/// A category's own budget only makes sense on its own until it has
/// sub-categories with budgets of their own — at that point, per product
/// decision, the sum of those sub-budgets *becomes* the parent's budget
/// (its own directly-set budget, if any, is superseded while any
/// sub-category is budgeted). This service is the single place that rule
/// lives, so every screen/total agrees and nothing double-counts a
/// sub-category's spend or budget under both itself and its parent.
class BudgetRollupService {
  BudgetRollupService(this._categoryRepo, this._budgetRepo, this._expenseRepo);

  final CategoryRepository _categoryRepo;
  final BudgetRepository _budgetRepo;
  final ExpenseRepository _expenseRepo;

  Future<EffectiveBudget> effectiveBudgetForCategory(
    int categoryId,
    int year,
    int month,
  ) async {
    final subs = await _categoryRepo.getSubCategories(categoryId);
    if (subs.isNotEmpty) {
      final subBudgets = <Budget>[];
      for (final sub in subs) {
        final budget = await _budgetRepo.getForCategoryMonth(sub.id, year, month);
        if (budget != null) subBudgets.add(budget);
      }
      if (subBudgets.isNotEmpty) {
        final min = subBudgets.fold<double>(0, (sum, b) => sum + b.minCost);
        final max = subBudgets.fold<double>(0, (sum, b) => sum + b.effectiveCeiling);
        return EffectiveBudget(min: min, max: max, fromSubCategories: true);
      }
    }
    final own = await _budgetRepo.getForCategoryMonth(categoryId, year, month);
    return EffectiveBudget(min: own?.minCost ?? 0, max: own?.maxCost, fromSubCategories: false);
  }

  /// [categoryId]'s own direct spend plus every sub-category's spend,
  /// mirroring the budget rollup above so actual and budget are compared
  /// on the same footing.
  Future<double> rolledUpActual(int categoryId, int year, int month) async {
    final start = startOfMonth(year, month);
    final end = startOfNextMonth(year, month);
    var total = await _expenseRepo.sumForCategoryInRange(categoryId, start, end);
    final subs = await _categoryRepo.getSubCategories(categoryId);
    for (final sub in subs) {
      total += await _expenseRepo.sumForCategoryInRange(sub.id, start, end);
    }
    return total;
  }

  /// The Dashboard/Budget Setup "Total Budget": Min-only, summed across
  /// every top-level category's *effective* budget (so a sub-budgeted
  /// category's Min is counted once, via its parent, never twice).
  Future<double> totalMinBudgetForMonth(int year, int month) async {
    final topLevel = await _categoryRepo.getTopLevel();
    var total = 0.0;
    for (final category in topLevel) {
      total += (await effectiveBudgetForCategory(category.id, year, month)).min;
    }
    return total;
  }

  /// Reference total matching [totalMinBudgetForMonth], but for the
  /// effective ceiling (Max if set, else Min) — shown alongside Total Min
  /// on the Budget Setup screen.
  Future<double> totalCeilingBudgetForMonth(int year, int month) async {
    final topLevel = await _categoryRepo.getTopLevel();
    var total = 0.0;
    for (final category in topLevel) {
      total += (await effectiveBudgetForCategory(category.id, year, month)).ceiling;
    }
    return total;
  }
}
