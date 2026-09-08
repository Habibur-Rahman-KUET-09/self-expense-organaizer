import 'package:drift/drift.dart';

import '../db/database.dart';

/// Wraps all Category queries (FR-1) so screens never touch drift directly.
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  /// All categories, including archived ones (e.g. for historical reports).
  Stream<List<Category>> watchAll() => _db.select(_db.categories).watch();

  /// Top-level categories (no parent). FR-1.1.
  Stream<List<Category>> watchTopLevel({bool activeOnly = true}) {
    final query = _db.select(_db.categories)
      ..where((c) => c.parentId.isNull());
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  /// Sub-categories under [parentId]. FR-1.2.
  Stream<List<Category>> watchSubCategories(
    int parentId, {
    bool activeOnly = true,
  }) {
    final query = _db.select(_db.categories)
      ..where((c) => c.parentId.equals(parentId));
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return query.watch();
  }

  Future<Category?> getById(int id) => (_db.select(
    _db.categories,
  )..where((c) => c.id.equals(id))).getSingleOrNull();

  /// One-off (non-reactive) equivalent of [watchTopLevel], for services that
  /// compute an aggregate once rather than watching it.
  Future<List<Category>> getTopLevel({bool activeOnly = true}) {
    final query = _db.select(_db.categories)
      ..where((c) => c.parentId.isNull());
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    return query.get();
  }

  /// One-off (non-reactive) equivalent of [watchSubCategories].
  Future<List<Category>> getSubCategories(
    int parentId, {
    bool activeOnly = true,
  }) {
    final query = _db.select(_db.categories)
      ..where((c) => c.parentId.equals(parentId));
    if (activeOnly) {
      query.where((c) => c.isActive.equals(true));
    }
    return query.get();
  }

  Future<int> add({
    required String name,
    int? parentId,
    int colorValue = 0xFF6750A4,
  }) {
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            parentId: Value(parentId),
            colorValue: Value(colorValue),
          ),
        );
  }

  Future<bool> update(Category category) =>
      _db.update(_db.categories).replace(category);

  /// FR-1.4: archive/unarchive without touching historical data.
  Future<int> setActive(int id, bool isActive) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(isActive: Value(isActive)),
    );
  }

  /// Hard-deletes a category. Throws [StateError] if it still has expenses,
  /// budgets, or sub-categories attached (NFR-3) — archive it instead via
  /// [setActive].
  Future<void> delete(int id) async {
    final hasExpenses = await (_db.select(
      _db.expenses,
    )..where((e) => e.categoryId.equals(id))).get();
    final hasBudgets = await (_db.select(
      _db.budgets,
    )..where((b) => b.categoryId.equals(id))).get();
    final hasChildren = await (_db.select(
      _db.categories,
    )..where((c) => c.parentId.equals(id))).get();
    if (hasExpenses.isNotEmpty || hasBudgets.isNotEmpty || hasChildren.isNotEmpty) {
      throw StateError(
        'Category has expenses, budgets, or sub-categories attached — '
        'archive it instead of deleting.',
      );
    }
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }
}
