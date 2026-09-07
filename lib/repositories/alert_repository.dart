import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all Alert log queries (FR-4.3–FR-4.5) so screens never touch drift
/// directly. Alerts are a log of threshold breaches that have fired, used to
/// avoid re-notifying at the same severity every time the dashboard opens.
class AlertRepository {
  AlertRepository(this._db);

  final AppDatabase _db;

  Stream<List<Alert>> watchForCategoryMonth(int categoryId, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final query = _db.select(_db.alerts)
      ..where(
        (a) =>
            a.categoryId.equals(categoryId) &
            a.dateTriggered.isBiggerOrEqualValue(start) &
            a.dateTriggered.isSmallerThanValue(end),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.dateTriggered)]);
    return query.watch();
  }

  Future<Alert?> latestForCategoryMonth(int categoryId, int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final query = _db.select(_db.alerts)
      ..where(
        (a) =>
            a.categoryId.equals(categoryId) &
            a.dateTriggered.isBiggerOrEqualValue(start) &
            a.dateTriggered.isSmallerThanValue(end),
      )
      ..orderBy([(a) => OrderingTerm.desc(a.dateTriggered)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Recent alerts across all categories, for the dashboard's alert banner.
  Stream<List<Alert>> watchRecent({int limit = 20}) {
    final query = _db.select(_db.alerts)
      ..orderBy([(a) => OrderingTerm.desc(a.dateTriggered)])
      ..limit(limit);
    return query.watch();
  }

  Future<int> log(AlertsCompanion companion) =>
      _db.into(_db.alerts).insert(companion);
}
