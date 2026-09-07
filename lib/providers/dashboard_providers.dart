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

  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final alertService = ref.watch(alertServiceProvider);

  final budgets = await ref.watch(budgetsForMonthProvider(monthKey).future);
  final totals = await budgetRepo.totalsForMonth(year, month);

  final start = startOfMonth(year, month);
  final end = startOfNextMonth(year, month);
  final totalActual = await expenseRepo.sumInRange(start, end);

  final progress = <CategoryProgress>[];
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
    progress.add(
      CategoryProgress(
        category: category,
        budget: budget,
        actual: actual,
        severity: severity,
      ),
    );
  }

  final daysTotal = daysInMonth(year, month);
  final daysElapsed = daysElapsedInMonth(now, year: year, month: month);
  final allowance = dailyAllowance(monthlyBudget: totals.max, daysInMonth: daysTotal);
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
    totalMin: totals.min,
    totalMax: totals.max,
    pace: pace,
    dailyAllowanceValue: allowance,
    cumulativeAllowedValue: allowed,
    categoryProgress: progress,
  );
});
