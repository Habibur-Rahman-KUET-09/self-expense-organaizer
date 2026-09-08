import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all Budget queries (FR-2, FR-4 threshold settings) so screens never
/// touch drift directly.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<List<Budget>> watchForMonth(int year, int month) {
    final query = _db.select(_db.budgets)
      ..where((b) => b.year.equals(year) & b.month.equals(month));
    return query.watch();
  }

  Future<List<Budget>> getForMonth(int year, int month) {
    return (_db.select(
      _db.budgets,
    )..where((b) => b.year.equals(year) & b.month.equals(month))).get();
  }

  Stream<Budget?> watchForCategoryMonth(int categoryId, int year, int month) {
    final query = _db.select(_db.budgets)..where(
      (b) =>
          b.categoryId.equals(categoryId) &
          b.year.equals(year) &
          b.month.equals(month),
    );
    return query.watchSingleOrNull();
  }

  Future<Budget?> getForCategoryMonth(int categoryId, int year, int month) {
    return (_db.select(_db.budgets)..where(
          (b) =>
              b.categoryId.equals(categoryId) &
              b.year.equals(year) &
              b.month.equals(month),
        ))
        .getSingleOrNull();
  }

  /// Insert or update the single budget row for the (categoryId, year,
  /// month) this [companion] describes. FR-2.1. [companion] must set
  /// categoryId, year, and month.
  Future<int> upsert(BudgetsCompanion companion) async {
    final categoryId = companion.categoryId.value;
    final year = companion.year.value;
    final month = companion.month.value;
    final existing = await getForCategoryMonth(categoryId, year, month);
    if (existing != null) {
      await (_db.update(
        _db.budgets,
      )..where((b) => b.id.equals(existing.id))).write(companion);
      return existing.id;
    }
    return _db.into(_db.budgets).insert(companion);
  }

  Future<int> delete(int id) =>
      (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();

  /// FR-2.2: copy all budgets from one month to another as a starting
  /// template. Categories that already have a budget for [toYear]/[toMonth]
  /// are left untouched.
  Future<void> copyForward({
    required int fromYear,
    required int fromMonth,
    required int toYear,
    required int toMonth,
  }) async {
    final source = await (_db.select(_db.budgets)..where(
          (b) => b.year.equals(fromYear) & b.month.equals(fromMonth),
        ))
        .get();
    await _db.batch((batch) {
      for (final budget in source) {
        batch.insert(
          _db.budgets,
          BudgetsCompanion.insert(
            categoryId: budget.categoryId,
            year: toYear,
            month: toMonth,
            minCost: Value(budget.minCost),
            maxCost: Value(budget.maxCost),
            thresholdPercent: Value(budget.thresholdPercent),
            thresholdBase: Value(budget.thresholdBase),
            noAlert: Value(budget.noAlert),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// FR-2.3: total monthly min/max across all categories. [max] only sums
  /// categories that actually have a Max set (unset ones contribute 0) —
  /// it's a reference figure, not the Dashboard's headline budget total,
  /// which is Min-only by design (see DashboardSummary.totalBudget).
  Future<({double min, double max})> totalsForMonth(int year, int month) async {
    final rows = await getForMonth(year, month);
    final min = rows.fold<double>(0, (sum, b) => sum + b.minCost);
    final max = rows.fold<double>(0, (sum, b) => sum + (b.maxCost ?? 0));
    return (min: min, max: max);
  }
}
