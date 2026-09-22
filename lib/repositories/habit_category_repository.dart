import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all HabitCategory queries so screens never touch drift directly.
/// Mirrors CategoryRepository, minus the parent/sub-category concept —
/// habit categories are a flat list.
class HabitCategoryRepository {
  HabitCategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<HabitCategory>> watchAll({bool activeOnly = true}) {
    final query = _db.select(_db.habitCategories);
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  Future<HabitCategory?> getById(int id) => (_db.select(
    _db.habitCategories,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  /// One-off (non-reactive) equivalent of [watchAll], for services that
  /// need the list once rather than watching it.
  Future<List<HabitCategory>> getAll({bool activeOnly = true}) {
    final query = _db.select(_db.habitCategories);
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.get();
  }

  Future<int> add({required String name, int colorValue = 0xFF6750A4}) {
    return _db
        .into(_db.habitCategories)
        .insert(
          HabitCategoriesCompanion.insert(
            name: name,
            colorValue: Value(colorValue),
          ),
        );
  }

  Future<bool> update(HabitCategory category) =>
      _db.update(_db.habitCategories).replace(category);

  Future<int> setActive(int id, bool isActive) {
    return (_db.update(_db.habitCategories)..where((c) => c.id.equals(id))).write(
      HabitCategoriesCompanion(isActive: Value(isActive)),
    );
  }

  /// Hard-deletes; throws if any habit still references this category —
  /// archive it instead via [setActive].
  Future<void> delete(int id) async {
    final hasHabits = await (_db.select(
      _db.habits,
    )..where((h) => h.categoryId.equals(id))).get();
    if (hasHabits.isNotEmpty) {
      throw StateError(
        'Category has habits attached — archive it instead of deleting.',
      );
    }
    await (_db.delete(_db.habitCategories)..where((c) => c.id.equals(id))).go();
  }
}
