import '../db/database.dart';
import '../logic/period_utils.dart';
import '../logic/threshold_checker.dart';
import '../models/enums.dart';
import '../repositories/alert_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/expense_repository.dart';

/// Coordinates the pure threshold-checking logic (lib/logic) with the
/// repositories: computes a category's current alert severity for FR-4.3,
/// and — since Phase 1 has no scheduled backend job to do this — records a
/// new Alert log entry whenever that severity has changed since the last
/// time it was checked, so the log in Section 6 reflects real history
/// rather than re-logging on every dashboard view.
class AlertService {
  AlertService(this._budgetRepo, this._expenseRepo, this._alertRepo);

  final BudgetRepository _budgetRepo;
  final ExpenseRepository _expenseRepo;
  final AlertRepository _alertRepo;

  Future<AlertType?> evaluateAndLog({
    required int categoryId,
    required int year,
    required int month,
  }) async {
    final budget = await _budgetRepo.getForCategoryMonth(categoryId, year, month);
    if (budget == null) return null;

    final start = startOfMonth(year, month);
    final end = startOfNextMonth(year, month);
    final actual = await _expenseRepo.sumForCategoryInRange(categoryId, start, end);

    final base = resolveThresholdBase(
      base: budget.thresholdBase,
      minCost: budget.minCost,
      maxCost: budget.maxCost,
    );
    final trigger = thresholdTriggerValue(
      thresholdBaseValue: base,
      thresholdPercent: budget.thresholdPercent,
    );
    final severity = classifySeverity(cumulativeActual: actual, triggerValue: trigger);
    if (severity == null) return null;

    final lastAlert = await _alertRepo.latestForCategoryMonth(categoryId, year, month);
    if (lastAlert?.type != severity) {
      await _alertRepo.log(
        AlertsCompanion.insert(
          categoryId: categoryId,
          dateTriggered: DateTime.now(),
          type: severity,
          valueAtTrigger: actual,
        ),
      );
    }
    return severity;
  }
}
