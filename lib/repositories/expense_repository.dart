import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all Expense queries (FR-5) so screens never touch drift directly.
/// Range queries take [startInclusive]/[endExclusive] so callers (the logic
/// layer) own period-boundary math (week/month/quarter/year) in one place.
class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Expense>> watchAll() {
    final query = _db.select(_db.expenses)
      ..orderBy([(e) => OrderingTerm.desc(e.date)]);
    return query.watch();
  }

  Stream<List<Expense>> watchInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.date.isBiggerOrEqualValue(startInclusive) &
            e.date.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.date)]);
    return query.watch();
  }

  Stream<List<Expense>> watchForCategoryInRange(
    int categoryId,
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final query = _db.select(_db.expenses)
      ..where(
        (e) =>
            e.categoryId.equals(categoryId) &
            e.date.isBiggerOrEqualValue(startInclusive) &
            e.date.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.date)]);
    return query.watch();
  }

  Future<double> sumForCategoryInRange(
    int categoryId,
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final sumExpr = _db.expenses.amount.sum();
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([sumExpr])
      ..where(
        _db.expenses.categoryId.equals(categoryId) &
            _db.expenses.date.isBiggerOrEqualValue(startInclusive) &
            _db.expenses.date.isSmallerThanValue(endExclusive),
      );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<double> sumInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final sumExpr = _db.expenses.amount.sum();
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([sumExpr])
      ..where(
        _db.expenses.date.isBiggerOrEqualValue(startInclusive) &
            _db.expenses.date.isSmallerThanValue(endExclusive),
      );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0;
  }

  Future<Expense?> getById(int id) => (_db.select(
    _db.expenses,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> add(ExpensesCompanion companion) =>
      _db.into(_db.expenses).insert(companion);

  Future<bool> update(Expense expense) =>
      _db.update(_db.expenses).replace(expense);

  Future<int> delete(int id) =>
      (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
}
