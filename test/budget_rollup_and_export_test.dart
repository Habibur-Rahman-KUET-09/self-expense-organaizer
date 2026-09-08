import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/dashboard_summary.dart';
import 'package:expense_tracker/providers/dashboard_providers.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/providers/service_providers.dart';
import 'package:expense_tracker/services/export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// See the equivalent helper in budget_min_max_test.dart for why this is
/// needed: a bare `container.read(provider.future)` doesn't keep an
/// autoDispose, multi-await FutureProvider alive long enough to resolve.
Future<DashboardSummary> _readDashboardSummary(ProviderContainer container) {
  final sub = container.listen(dashboardSummaryProvider, (_, _) {});
  return container.read(dashboardSummaryProvider.future).whenComplete(sub.close);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  group('BudgetRollupService', () {
    test('a category with no sub-budgets uses its own budget', () async {
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: 2026,
          month: 9,
          minCost: const Value(1000),
          maxCost: const Value(2000),
        ),
      );

      final effective = await container
          .read(budgetRollupServiceProvider)
          .effectiveBudgetForCategory(foodId, 2026, 9);

      expect(effective.min, 1000);
      expect(effective.max, 2000);
      expect(effective.fromSubCategories, isFalse);
    });

    test(
      "sub-category budgets sum to become the parent's budget",
      () async {
        final categoryRepo = container.read(categoryRepositoryProvider);
        final budgetRepo = container.read(budgetRepositoryProvider);
        final foodId = await categoryRepo.add(name: 'Food');
        final groceriesId = await categoryRepo.add(name: 'Groceries', parentId: foodId);
        final diningId = await categoryRepo.add(name: 'Dining Out', parentId: foodId);

        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: groceriesId,
            year: 2026,
            month: 9,
            minCost: const Value(2000),
            maxCost: const Value(3000),
          ),
        );
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: diningId,
            year: 2026,
            month: 9,
            minCost: const Value(1000),
            // Max intentionally left unset -> effectiveCeiling falls back
            // to its own Min (1000) when summed.
          ),
        );

        final effective = await container
            .read(budgetRollupServiceProvider)
            .effectiveBudgetForCategory(foodId, 2026, 9);

        expect(effective.min, 3000); // 2000 + 1000
        expect(effective.max, 4000); // 3000 + 1000 (dining's effective ceiling)
        expect(effective.fromSubCategories, isTrue);
      },
    );

    test(
      "a parent's own budget is superseded once any sub-category has one",
      () async {
        final categoryRepo = container.read(categoryRepositoryProvider);
        final budgetRepo = container.read(budgetRepositoryProvider);
        final foodId = await categoryRepo.add(name: 'Food');
        final groceriesId = await categoryRepo.add(name: 'Groceries', parentId: foodId);

        // The parent has its own (now-stale) budget on file...
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: foodId,
            year: 2026,
            month: 9,
            minCost: const Value(9999),
          ),
        );
        // ...but once a sub-category is budgeted, that supersedes it.
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: groceriesId,
            year: 2026,
            month: 9,
            minCost: const Value(1500),
          ),
        );

        final effective = await container
            .read(budgetRollupServiceProvider)
            .effectiveBudgetForCategory(foodId, 2026, 9);

        expect(effective.min, 1500); // not 9999, and not 9999 + 1500
        expect(effective.fromSubCategories, isTrue);
      },
    );

    test(
      'falls back to its own budget when sub-categories exist but none are budgeted',
      () async {
        final categoryRepo = container.read(categoryRepositoryProvider);
        final budgetRepo = container.read(budgetRepositoryProvider);
        final foodId = await categoryRepo.add(name: 'Food');
        await categoryRepo.add(name: 'Groceries', parentId: foodId); // unbudgeted
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: foodId,
            year: 2026,
            month: 9,
            minCost: const Value(1200),
          ),
        );

        final effective = await container
            .read(budgetRollupServiceProvider)
            .effectiveBudgetForCategory(foodId, 2026, 9);

        expect(effective.min, 1200);
        expect(effective.fromSubCategories, isFalse);
      },
    );

    test('rolledUpActual sums the category\'s own spend plus every sub-category\'s', () async {
      final categoryRepo = container.read(categoryRepositoryProvider);
      final expenseRepo = container.read(expenseRepositoryProvider);
      final foodId = await categoryRepo.add(name: 'Food');
      final groceriesId = await categoryRepo.add(name: 'Groceries', parentId: foodId);
      final date = DateTime(2026, 9, 15);

      await expenseRepo.add(
        ExpensesCompanion.insert(categoryId: foodId, date: date, amount: 200),
      );
      await expenseRepo.add(
        ExpensesCompanion.insert(categoryId: groceriesId, date: date, amount: 300),
      );

      final actual = await container
          .read(budgetRollupServiceProvider)
          .rolledUpActual(foodId, 2026, 9);

      expect(actual, 500);
    });

    test(
      'totalMinBudgetForMonth counts each sub-budgeted category once, via its parent',
      () async {
        final categoryRepo = container.read(categoryRepositoryProvider);
        final budgetRepo = container.read(budgetRepositoryProvider);
        final foodId = await categoryRepo.add(name: 'Food');
        final groceriesId = await categoryRepo.add(name: 'Groceries', parentId: foodId);
        final transportId = await categoryRepo.add(name: 'Transport'); // no subs

        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: foodId,
            year: 2026,
            month: 9,
            minCost: const Value(9999), // stale, superseded by Groceries below
          ),
        );
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: groceriesId,
            year: 2026,
            month: 9,
            minCost: const Value(2000),
          ),
        );
        await budgetRepo.upsert(
          BudgetsCompanion.insert(
            categoryId: transportId,
            year: 2026,
            month: 9,
            minCost: const Value(500),
          ),
        );

        final total = await container
            .read(budgetRollupServiceProvider)
            .totalMinBudgetForMonth(2026, 9);

        expect(total, 2500); // 2000 (via Food/Groceries) + 500 (Transport)
      },
    );
  });

  test(
    "Dashboard's Top Spending only ever lists top-level categories, rolled up",
    () async {
      final categoryRepo = container.read(categoryRepositoryProvider);
      final budgetRepo = container.read(budgetRepositoryProvider);
      final expenseRepo = container.read(expenseRepositoryProvider);
      final now = DateTime.now();

      final foodId = await categoryRepo.add(name: 'Food');
      final groceriesId = await categoryRepo.add(name: 'Groceries', parentId: foodId);
      await budgetRepo.upsert(
        BudgetsCompanion.insert(
          categoryId: groceriesId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
        ),
      );
      await expenseRepo.add(
        ExpensesCompanion.insert(categoryId: groceriesId, date: now, amount: 400),
      );

      final summary = await _readDashboardSummary(container);

      expect(summary.topLevelProgress, hasLength(1));
      final foodProgress = summary.topLevelProgress.single;
      expect(foodProgress.category.name, 'Food'); // never "Groceries"
      expect(foodProgress.fromSubCategories, isTrue);
      expect(foodProgress.effectiveMin, 1000);
      expect(foodProgress.actual, 400); // rolled up from Groceries
    },
  );

  group('ExportService', () {
    test('JSON backup includes categories, budgets, expenses, and alerts', () async {
      final categoryRepo = container.read(categoryRepositoryProvider);
      final foodId = await categoryRepo.add(name: 'Food', colorValue: 0xFFE53935);
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: 2026,
          month: 9,
          minCost: const Value(1000),
        ),
      );
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(
          categoryId: foodId,
          date: DateTime(2026, 9, 10),
          amount: 250,
          note: const Value('Lunch'),
        ),
      );

      final json = await ExportService(db).buildJsonBackup();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['categories'], hasLength(1));
      expect((decoded['categories'] as List).first['name'], 'Food');
      expect(decoded['budgets'], hasLength(1));
      expect(decoded['expenses'], hasLength(1));
      expect((decoded['expenses'] as List).first['note'], 'Lunch');
      expect(decoded['alerts'], isEmpty);
    });

    test('CSV export lists expenses with resolved category names', () async {
      final categoryRepo = container.read(categoryRepositoryProvider);
      final foodId = await categoryRepo.add(name: 'Food');
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(
          categoryId: foodId,
          date: DateTime(2026, 9, 10),
          amount: 250,
        ),
      );

      final csv = await ExportService(db).buildExpensesCsv();
      final lines = csv.trim().split('\n');

      expect(lines.first, 'Date,Category,Amount,Note');
      expect(lines[1], contains('Food'));
      expect(lines[1], contains('250'));
      expect(lines[1], contains('2026-09-10'));
    });

    test('CSV export quotes fields containing commas', () async {
      final categoryRepo = container.read(categoryRepositoryProvider);
      final foodId = await categoryRepo.add(name: 'Food');
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(
          categoryId: foodId,
          date: DateTime(2026, 9, 10),
          amount: 250,
          note: const Value('milk, eggs'),
        ),
      );

      final csv = await ExportService(db).buildExpensesCsv();

      expect(csv, contains('"milk, eggs"'));
    });
  });
}
