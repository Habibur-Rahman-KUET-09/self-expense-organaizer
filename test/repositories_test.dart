import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/repositories/alert_repository.dart';
import 'package:expense_tracker/repositories/budget_repository.dart';
import 'package:expense_tracker/repositories/category_repository.dart';
import 'package:expense_tracker/repositories/expense_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late BudgetRepository budgetRepo;
  late ExpenseRepository expenseRepo;
  late AlertRepository alertRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    budgetRepo = BudgetRepository(db);
    expenseRepo = ExpenseRepository(db);
    alertRepo = AlertRepository(db);
  });

  tearDown(() => db.close());

  test('category CRUD and sub-category listing (FR-1)', () async {
    final foodId = await categoryRepo.add(name: 'Food', colorValue: 0xFFE53935);
    final groceriesId = await categoryRepo.add(
      name: 'Groceries',
      parentId: foodId,
    );

    final topLevel = await categoryRepo.watchTopLevel().first;
    expect(topLevel.map((c) => c.name), ['Food']);

    final subs = await categoryRepo.watchSubCategories(foodId).first;
    expect(subs.map((c) => c.name), ['Groceries']);

    // FR-1.4: archiving hides from active queries but keeps the row.
    await categoryRepo.setActive(groceriesId, false);
    final activeSubs = await categoryRepo.watchSubCategories(foodId).first;
    expect(activeSubs, isEmpty);
    final allSubs = await categoryRepo
        .watchSubCategories(foodId, activeOnly: false)
        .first;
    expect(allSubs, hasLength(1));
  });

  test('deleting a category with expenses is rejected (NFR-3)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    await expenseRepo.add(
      ExpensesCompanion.insert(
        categoryId: foodId,
        date: DateTime(2026, 9, 1),
        amount: 100,
      ),
    );
    expect(() => categoryRepo.delete(foodId), throwsStateError);
  });

  test('budget upsert is idempotent per category/month (FR-2.1)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 9,
        minCost: const Value(3000),
        maxCost: const Value(5000),
        thresholdPercent: const Value(80),
        thresholdBase: const Value(ThresholdBase.max),
      ),
    );
    // Second upsert for the same category/month should update, not insert.
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 9,
        maxCost: const Value(6000),
      ),
    );

    final all = await budgetRepo.watchForMonth(2026, 9).first;
    expect(all, hasLength(1));
    expect(all.single.maxCost, 6000);
  });

  test('budget totals sum across categories (FR-2.3)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    final transportId = await categoryRepo.add(name: 'Transport');
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 9,
        maxCost: const Value(5000),
      ),
    );
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: transportId,
        year: 2026,
        month: 9,
        maxCost: const Value(2000),
      ),
    );

    final totals = await budgetRepo.totalsForMonth(2026, 9);
    expect(totals.max, 7000);
  });

  test('copyForward does not clobber existing budgets (FR-2.2)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 8,
        maxCost: const Value(5000),
      ),
    );
    await budgetRepo.upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 9,
        maxCost: const Value(9999),
      ),
    );

    await budgetRepo.copyForward(
      fromYear: 2026,
      fromMonth: 8,
      toYear: 2026,
      toMonth: 9,
    );

    final sept = await budgetRepo.getForCategoryMonth(foodId, 2026, 9);
    expect(sept!.maxCost, 9999); // untouched, not overwritten by the copy
  });

  test('expense range sums are scoped correctly (FR-5, feeds FR-3)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    final transportId = await categoryRepo.add(name: 'Transport');
    await expenseRepo.add(
      ExpensesCompanion.insert(categoryId: foodId, date: DateTime(2026, 9, 3), amount: 200),
    );
    await expenseRepo.add(
      ExpensesCompanion.insert(categoryId: foodId, date: DateTime(2026, 9, 10), amount: 150),
    );
    await expenseRepo.add(
      ExpensesCompanion.insert(categoryId: transportId, date: DateTime(2026, 9, 5), amount: 500),
    );
    // Outside the range — must not be counted.
    await expenseRepo.add(
      ExpensesCompanion.insert(categoryId: foodId, date: DateTime(2026, 10, 1), amount: 999),
    );

    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 10, 1);
    final foodTotal = await expenseRepo.sumForCategoryInRange(foodId, start, end);
    expect(foodTotal, 350);

    final grandTotal = await expenseRepo.sumInRange(start, end);
    expect(grandTotal, 850);
  });

  test('alert log stores and retrieves latest severity per category/month (FR-4)', () async {
    final foodId = await categoryRepo.add(name: 'Food');
    await alertRepo.log(
      AlertsCompanion.insert(
        categoryId: foodId,
        dateTriggered: DateTime(2026, 9, 10),
        type: AlertType.approaching,
        valueAtTrigger: 4000,
      ),
    );
    await alertRepo.log(
      AlertsCompanion.insert(
        categoryId: foodId,
        dateTriggered: DateTime(2026, 9, 20),
        type: AlertType.exceeded,
        valueAtTrigger: 5200,
      ),
    );

    final latest = await alertRepo.latestForCategoryMonth(foodId, 2026, 9);
    expect(latest!.type, AlertType.exceeded);

    final all = await alertRepo.watchForCategoryMonth(foodId, 2026, 9).first;
    expect(all, hasLength(2));
  });
}
