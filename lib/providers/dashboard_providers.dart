import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/daily_budget.dart';
import '../logic/period_utils.dart';
import '../models/dashboard_summary.dart';
import 'budget_providers.dart';
import 'database_providers.dart';
import 'expense_providers.dart';
import 'service_providers.dart';

/// FR-8.1: aggregates the current month's total spend vs budget, daily
/// pace, and per-category progress (which active alerts and top-spending
/// categories are derived from). Recomputes whenever this month's budgets
/// or expenses change.
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  final monthKey = (year: year, month: month);

  // Pure reactive trigger — see expensesInMonthProvider's doc comment.
  ref.watch(expensesInMonthProvider(monthKey));

  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final alertService = ref.watch(alertServiceProvider);
  final rollupService = ref.watch(budgetRollupServiceProvider);

  final start = startOfMonth(year, month);
  final end = startOfNextMonth(year, month);
  final totalActual = await expenseRepo.sumInRange(start, end);

  // Any-level budgeted categories, for the Active Alerts banner — alerts
  // still fire per individual (sub-)category using its own threshold
  // settings, unaffected by the rollup below.
  final budgets = await ref.watch(budgetsForMonthProvider(monthKey).future);
  final alertProgress = <CategoryProgress>[];
  for (final budget in budgets) {
    final category = await categoryRepo.getById(budget.categoryId);
    if (category == null) continue;
    final actual = await expenseRepo.sumForCategoryInRange(
      budget.categoryId,
      start,
      end,
    );
    final severity = await alertService.evaluateAndLog(
      categoryId: budget.categoryId,
      year: year,
      month: month,
    );
    alertProgress.add(
      CategoryProgress(
        category: category,
        budget: budget,
        actual: actual,
        severity: severity,
      ),
    );
  }

  // Top-level-only, rolled-up categories (sub-category spend/budget folded
  // into their parent) for Top Spending and the Total Budget figure — see
  // BudgetRollupService for why.
  final topLevelCategories = await categoryRepo.getTopLevel();
  final topLevelProgress = <TopLevelBudgetProgress>[];
  var totalBudget = 0.0;
  for (final category in topLevelCategories) {
    final effective = await rollupService.effectiveBudgetForCategory(
      category.id,
      year,
      month,
    );
    if (!effective.hasBudget) continue;
    final actual = await rollupService.rolledUpActual(category.id, year, month);
    totalBudget += effective.min;
    topLevelProgress.add(
      TopLevelBudgetProgress(
        category: category,
        effectiveMin: effective.min,
        effectiveMax: effective.max,
        fromSubCategories: effective.fromSubCategories,
        actual: actual,
      ),
    );
  }

  final daysTotal = daysInMonth(year, month);
  final daysElapsed = daysElapsedInMonth(now, year: year, month: month);
  // Dashboard's Total Budget is always the sum of Minimums (see
  // DashboardSummary.totalBudget) — Max never factors into it.
  final allowance = dailyAllowance(monthlyBudget: totalBudget, daysInMonth: daysTotal);
  final allowed = cumulativeAllowed(
    dailyAllowanceValue: allowance,
    daysElapsed: daysElapsed,
  );
  final pace = paceStatus(
    cumulativeActual: totalActual,
    cumulativeAllowedValue: allowed,
  );

  return DashboardSummary(
    totalActual: totalActual,
    totalBudget: totalBudget,
    pace: pace,
    dailyAllowanceValue: allowance,
    cumulativeAllowedValue: allowed,
    categoryProgress: alertProgress,
    topLevelProgress: topLevelProgress,
  );
});
