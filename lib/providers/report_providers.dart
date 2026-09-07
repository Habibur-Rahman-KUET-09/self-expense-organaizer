import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/period_utils.dart';
import '../logic/trend_projection.dart';
import '../models/enums.dart';
import 'database_providers.dart';

typedef PeriodKey = ({ReportPeriod period, int offset});

/// Per-category totals for one period/offset (FR-6.2's category breakdown).
/// Also the source for "current total" (sum of all values) and, filtered by
/// category, the single-category total used elsewhere on the screen.
final periodCategoryBreakdownProvider = FutureProvider.autoDispose
    .family<Map<int, double>, PeriodKey>((ref, key) {
      final (start, end) = reportPeriodRange(key.period, DateTime.now(), key.offset);
      return ref.watch(expenseRepositoryProvider).sumByCategoryInRange(start, end);
    });

typedef TrendKey = ({ReportPeriod period, int count, int? categoryId});

/// The last [TrendKey.count] periods' totals (oldest first, current period
/// last) — FR-6.3's trend line chart. Filtered to one category when
/// [TrendKey.categoryId] is set.
final periodTrendProvider = FutureProvider.autoDispose
    .family<List<double>, TrendKey>((ref, key) async {
      final repo = ref.watch(expenseRepositoryProvider);
      final totals = <double>[];
      for (var i = key.count - 1; i >= 0; i--) {
        final (start, end) = reportPeriodRange(key.period, DateTime.now(), -i);
        final total = key.categoryId == null
            ? await repo.sumInRange(start, end)
            : await repo.sumForCategoryInRange(key.categoryId!, start, end);
        totals.add(total);
      }
      return totals;
    });

typedef ProjectionKey = ({ReportPeriod period, int? categoryId});

/// FR-7: projects the next period from the last 3 *completed* periods
/// (offsets -3..-1, excluding the still-in-progress current one), and the
/// max budget the most recently completed period was measured against.
final periodProjectionProvider = FutureProvider.autoDispose
    .family<ProjectionResult, ProjectionKey>((ref, key) async {
      const periodsToAverage = 3;
      final repo = ref.watch(expenseRepositoryProvider);
      final actuals = <double>[];
      for (var i = periodsToAverage; i >= 1; i--) {
        final (start, end) = reportPeriodRange(key.period, DateTime.now(), -i);
        final total = key.categoryId == null
            ? await repo.sumInRange(start, end)
            : await repo.sumForCategoryInRange(key.categoryId!, start, end);
        actuals.add(total);
      }
      final maxBudget = await _maxBudgetForPeriod(
        ref,
        key.period,
        -1,
        categoryId: key.categoryId,
      );
      return projectNextPeriod(recentActuals: actuals, maxBudget: maxBudget);
    });

/// Budgets are only defined per category per month (Section 6), so a
/// week/quarter/year's "max budget" is approximated as the sum of the
/// monthly max budgets for every calendar month the period overlaps. For a
/// week that straddles two months this double-counts each month's full
/// budget rather than prorating by overlap — an accepted Phase 1
/// simplification given budgets have no finer-grained native unit.
Future<double> _maxBudgetForPeriod(
  Ref ref,
  ReportPeriod period,
  int offset, {
  int? categoryId,
}) async {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final (start, end) = reportPeriodRange(period, DateTime.now(), offset);
  var total = 0.0;
  var cursor = DateTime(start.year, start.month);
  while (cursor.isBefore(end)) {
    if (categoryId == null) {
      final totals = await budgetRepo.totalsForMonth(cursor.year, cursor.month);
      total += totals.max;
    } else {
      final budget = await budgetRepo.getForCategoryMonth(
        categoryId,
        cursor.year,
        cursor.month,
      );
      total += budget?.maxCost ?? 0;
    }
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return total;
}
