import '../db/database.dart';
import '../logic/daily_budget.dart';
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
  final AlertType? severity;

  double get percentOfMax =>
      budget.maxCost <= 0 ? 0 : (actual / budget.maxCost) * 100;
}

/// FR-8.1's dashboard data: current month total spend vs budget, daily
/// pace, and per-category progress (used to derive active alerts and top
/// spending categories).
class DashboardSummary {
  const DashboardSummary({
    required this.totalActual,
    required this.totalMin,
    required this.totalMax,
    required this.pace,
    required this.dailyAllowanceValue,
    required this.cumulativeAllowedValue,
    required this.categoryProgress,
  });

  final double totalActual;
  final double totalMin;
  final double totalMax;
  final PaceStatus pace;
  final double dailyAllowanceValue;
  final double cumulativeAllowedValue;
  final List<CategoryProgress> categoryProgress;

  List<CategoryProgress> get activeAlerts =>
      categoryProgress.where((c) => c.severity != null).toList();

  List<CategoryProgress> get topSpending {
    final sorted = [...categoryProgress]
      ..sort((a, b) => b.percentOfMax.compareTo(a.percentOfMax));
    return sorted.take(3).toList();
  }
}
