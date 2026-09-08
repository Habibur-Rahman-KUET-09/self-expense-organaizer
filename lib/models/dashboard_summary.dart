import '../db/database.dart';
import '../logic/daily_budget.dart';
import 'budget_extensions.dart';
import 'enums.dart';

/// A single budgeted category's month-to-date progress, combining its
/// budget row with its actual spend and current alert severity.
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.budget,
    required this.actual,
    required this.severity,
  });

  final Category category;
  final Budget budget;
  final double actual;

  /// Null when alerts are on ([Budget.noAlert] is false) but nothing is
  /// due, or when [Budget.noAlert] is true — either way, no active alert.
  final AlertType? severity;

  /// Spend as a percentage of this category's own effective ceiling (Max
  /// if set, otherwise Min).
  double get percentOfBudget => budget.effectiveCeiling <= 0
      ? 0
      : (actual / budget.effectiveCeiling) * 100;

  /// Expense ≥ category budget — drives the strikethrough display. Shown
  /// regardless of [Budget.noAlert] (that only silences the alert banner).
  bool get isOverBudget =>
      budget.effectiveCeiling > 0 && actual >= budget.effectiveCeiling;
}

/// FR-8.1's dashboard data: current month total spend vs budget, daily
/// pace, and per-category progress (used to derive active alerts and top
/// spending categories).
class DashboardSummary {
  const DashboardSummary({
    required this.totalActual,
    required this.totalBudget,
    required this.pace,
    required this.dailyAllowanceValue,
    required this.cumulativeAllowedValue,
    required this.categoryProgress,
  });

  final double totalActual;

  /// The Dashboard's headline budget figure: always the sum of every
  /// budgeted category's Minimum for the month. Maximum never enters into
  /// this total, by design — Max is a per-category soft ceiling only.
  final double totalBudget;

  final PaceStatus pace;
  final double dailyAllowanceValue;
  final double cumulativeAllowedValue;
  final List<CategoryProgress> categoryProgress;

  List<CategoryProgress> get activeAlerts =>
      categoryProgress.where((c) => c.severity != null).toList();

  List<CategoryProgress> get topSpending {
    final sorted = [...categoryProgress]
      ..sort((a, b) => b.percentOfBudget.compareTo(a.percentOfBudget));
    return sorted.take(3).toList();
  }
}
