import '../db/database.dart';
import '../logic/daily_budget.dart';
import 'enums.dart';

/// A single budgeted category's (any level — top or sub) month-to-date
/// progress against its own budget row, used for the Active Alerts banner
/// only. See [TopLevelBudgetProgress] for the Dashboard's per-category
/// display, which rolls sub-categories into their parent instead.
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
}

/// A *top-level* category's rolled-up month-to-date progress: its own
/// direct spend plus every sub-category's spend, against its own budget or
/// — when any sub-category has one — the sum of its sub-categories'
/// budgets (see BudgetRollupService). This is what the Dashboard's "Top
/// Spending Categories" and headline Total Budget are built from, so a
/// sub-category's numbers are only ever represented once, via its parent,
/// and every entry shown is unambiguously a top-level category.
class TopLevelBudgetProgress {
  const TopLevelBudgetProgress({
    required this.category,
    required this.effectiveMin,
    required this.effectiveMax,
    required this.fromSubCategories,
    required this.actual,
  });

  final Category category;
  final double effectiveMin;
  final double? effectiveMax;

  /// Whether [effectiveMin]/[effectiveMax] came from summing sub-category
  /// budgets rather than this category's own budget row.
  final bool fromSubCategories;
  final double actual;

  double get effectiveCeiling => effectiveMax ?? effectiveMin;

  double get percentOfBudget =>
      effectiveCeiling <= 0 ? 0 : (actual / effectiveCeiling) * 100;

  /// Expense ≥ category budget — drives the strikethrough display.
  bool get isOverBudget => effectiveCeiling > 0 && actual >= effectiveCeiling;
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
    required this.topLevelProgress,
  });

  final double totalActual;

  /// The Dashboard's headline budget figure: always the sum of every
  /// top-level category's effective Minimum for the month (sub-category
  /// budgets rolled into their parent — see BudgetRollupService). Maximum
  /// never enters into this total, by design.
  final double totalBudget;

  final PaceStatus pace;
  final double dailyAllowanceValue;
  final double cumulativeAllowedValue;

  /// Any-level budgeted categories, for the Active Alerts banner.
  final List<CategoryProgress> categoryProgress;

  /// Top-level-only, rolled-up categories, for the Top Spending list.
  final List<TopLevelBudgetProgress> topLevelProgress;

  List<CategoryProgress> get activeAlerts =>
      categoryProgress.where((c) => c.severity != null).toList();

  List<TopLevelBudgetProgress> get topSpending {
    final sorted = [...topLevelProgress]
      ..sort((a, b) => b.percentOfBudget.compareTo(a.percentOfBudget));
    return sorted.take(3).toList();
  }
}
