import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all HabitLog queries (Habit Tracker RS §4.2 daily logging) so
/// screens never touch drift directly.
class HabitLogRepository {
  HabitLogRepository(this._db);

  final AppDatabase _db;

  /// Every logged day across every habit — used purely as a reactive
  /// trigger (its emitted list isn't read directly) so streak/completion
  /// providers recompute whenever any log changes, including a backfilled
  /// past date that a narrower "today only" watch would miss.
  Stream<List<HabitLog>> watchAll() => _db.select(_db.habitLogs).watch();

  Stream<List<HabitLog>> watchForHabitInRange(
    int habitId,
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final query = _db.select(_db.habitLogs)
      ..where(
        (l) =>
            l.habitId.equals(habitId) &
            l.logDate.isBiggerOrEqualValue(startInclusive) &
            l.logDate.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(l) => OrderingTerm.asc(l.logDate)]);
    return query.watch();
  }

  Future<List<HabitLog>> getForHabitInRange(
    int habitId,
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final query = _db.select(_db.habitLogs)
      ..where(
        (l) =>
            l.habitId.equals(habitId) &
            l.logDate.isBiggerOrEqualValue(startInclusive) &
            l.logDate.isSmallerThanValue(endExclusive),
      );
    return query.get();
  }

  /// All habits' logs for the single calendar day containing [date] — one
  /// query for the Today screen instead of one per habit.
  Stream<List<HabitLog>> watchAllForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final query = _db.select(_db.habitLogs)..where((l) => l.logDate.equals(day));
    return query.watch();
  }

  Future<HabitLog?> getForHabitOnDay(int habitId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return (_db.select(_db.habitLogs)..where(
          (l) => l.habitId.equals(habitId) & l.logDate.equals(day),
        ))
        .getSingleOrNull();
  }

  /// Insert or replace the log for [habitId] on [date] — a habit has at
  /// most one log per day (see HabitLogs.uniqueKeys), so logging again
  /// just overwrites the value/note rather than adding a second entry.
  Future<void> logDay({
    required int habitId,
    required DateTime date,
    double? value,
    String? note,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final existing = await getForHabitOnDay(habitId, day);
    final companion = HabitLogsCompanion.insert(
      habitId: habitId,
      logDate: day,
      value: Value(value),
      note: Value(note),
    );
    if (existing != null) {
      await (_db.update(_db.habitLogs)..where((l) => l.id.equals(existing.id))).write(
        companion,
      );
    } else {
      await _db.into(_db.habitLogs).insert(companion);
    }
  }

  Future<void> deleteForDay(int habitId, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    await (_db.delete(_db.habitLogs)
          ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(day)))
        .go();
  }

  Future<int> delete(int id) =>
      (_db.delete(_db.habitLogs)..where((l) => l.id.equals(id))).go();
}
