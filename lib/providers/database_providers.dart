import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../repositories/alert_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/expense_repository.dart';

/// Single app-lifetime database connection. Everything else (repositories,
/// screens) reaches the database only through this provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(appDatabaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(ref.watch(appDatabaseProvider));
});
