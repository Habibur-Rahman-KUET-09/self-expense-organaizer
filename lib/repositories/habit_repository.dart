import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all Habit queries (Habit Tracker RS §4.1) so screens never touch
/// drift directly.
class HabitRepository {
  HabitRepository(this._db);

  final AppDatabase _db;

  Stream<List<Habit>> watchAll({bool activeOnly = true}) {
    final query = _db.select(_db.habits);
    if (activeOnly) {
      query.where((h) => h.isActive.equals(true));
    }
    query.orderBy([
      (h) => OrderingTerm.asc(h.sortOrder),
      (h) => OrderingTerm.asc(h.name),
    ]);
    return query.watch();
  }

  Future<List<Habit>> getAll({bool activeOnly = true}) {
    final query = _db.select(_db.habits);
    if (activeOnly) {
      query.where((h) => h.isActive.equals(true));
    }
    query.orderBy([
      (h) => OrderingTerm.asc(h.sortOrder),
      (h) => OrderingTerm.asc(h.name),
    ]);
    return query.get();
  }

  Future<Habit?> getById(int id) =>
      (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingleOrNull();

  Future<int> add(HabitsCompanion companion) =>
      _db.into(_db.habits).insert(companion);

  Future<bool> update(Habit habit) => _db.update(_db.habits).replace(habit);

  Future<int> setActive(int id, bool isActive) {
    return (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(isActive: Value(isActive)),
    );
  }

  /// Persists a new relative order for exactly the habits in
  /// [habitIdsInOrder] (Habit Tracker RS §4.1 "reordering/pinning").
  Future<void> reorder(List<int> habitIdsInOrder) async {
    await _db.transaction(() async {
      for (var i = 0; i < habitIdsInOrder.length; i++) {
        await (_db.update(_db.habits)..where((h) => h.id.equals(habitIdsInOrder[i]))).write(
          HabitsCompanion(sortOrder: Value(i)),
        );
      }
    });
  }

  /// Hard-deletes; throws if the habit has any logged history — archive it
  /// instead via [setActive] (mirrors CategoryRepository.delete).
  Future<void> delete(int id) async {
    final hasLogs = await (_db.select(
      _db.habitLogs,
    )..where((l) => l.habitId.equals(id))..limit(1)).get();
    if (hasLogs.isNotEmpty) {
      throw StateError(
        'Habit has logged history — archive it instead of deleting.',
      );
    }
    await (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();
  }
}
