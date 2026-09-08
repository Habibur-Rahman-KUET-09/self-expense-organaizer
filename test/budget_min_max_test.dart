import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/budget_extensions.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/models/dashboard_summary.dart';
import 'package:expense_tracker/providers/dashboard_providers.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// dashboardSummaryProvider is autoDispose with a multi-await body; a bare
/// `container.read(provider.future)` doesn't hold it alive across those
/// awaits (nothing is "listening"), so it can get disposed mid-flight.
/// Holding a listener for the duration of the read avoids that.
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

  test('a budget can be saved with only Min set (Max is optional)', () async {
    final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
    await container.read(budgetRepositoryProvider).upsert(
      BudgetsCompanion.insert(
        categoryId: foodId,
        year: 2026,
        month: 9,
        minCost: const Value(1000),
      ),
    );

    final budget = await container
        .read(budgetRepositoryProvider)
        .getForCategoryMonth(foodId, 2026, 9);

    expect(budget!.minCost, 1000);
    expect(budget.maxCost, isNull);
    expect(budget.effectiveCeiling, 1000); // falls back to min
  });

  test(
    "Dashboard's Total Budget sums only Minimums, never Maximums",
    () async {
      final now = DateTime.now();
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
      final transportId = await container
          .read(categoryRepositoryProvider)
          .add(name: 'Transport');
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
          maxCost: const Value(5000), // large Max must NOT inflate the total
        ),
      );
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: transportId,
          year: now.year,
          month: now.month,
          minCost: const Value(2000), // no Max at all
        ),
      );

      final summary = await _readDashboardSummary(container);

      expect(summary.totalBudget, 3000); // 1000 + 2000, not 1000 + 5000
    },
  );

  test(
    'strikethrough (isOverBudget) fires at the effective ceiling and resets per month',
    () async {
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
      // Min-only budget: ceiling is 1000.
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
          date: DateTime(2026, 9, 15),
          amount: 1000, // exactly at the ceiling -> over budget
        ),
      );

      final september = await container
          .read(budgetRepositoryProvider)
          .getForCategoryMonth(foodId, 2026, 9);
      final septemberActual = await container
          .read(expenseRepositoryProvider)
          .sumForCategoryInRange(foodId, DateTime(2026, 9), DateTime(2026, 10));
      expect(septemberActual >= september!.effectiveCeiling, isTrue);

      // October has no expenses yet — same category, budget resets per
      // month since actual is always computed fresh for that month.
      final octoberActual = await container
          .read(expenseRepositoryProvider)
          .sumForCategoryInRange(foodId, DateTime(2026, 10), DateTime(2026, 11));
      expect(octoberActual, 0);
      expect(octoberActual >= september.effectiveCeiling, isFalse);
    },
  );

  test(
    '"No Alert Needed" suppresses the alert but keeps tracking/calculation normal',
    () async {
      final now = DateTime.now();
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
          maxCost: const Value(2000),
          thresholdPercent: const Value(50), // trigger = 1000
          noAlert: const Value(true),
        ),
      );
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 1500),
      );

      final summary = await _readDashboardSummary(container);
      final foodProgress = summary.categoryProgress.single;

      // Tracking/calculation stays normal: actual, percentage, and the
      // strikethrough indicator are all still computed.
      expect(foodProgress.actual, 1500);
      expect(foodProgress.percentOfBudget, 75); // 1500 / 2000 effective ceiling
      expect(foodProgress.isOverBudget, isFalse); // 1500 < 2000 ceiling

      // But no alert fires, and nothing was logged.
      expect(foodProgress.severity, isNull);
      expect(summary.activeAlerts, isEmpty);
      final loggedAlert = await container
          .read(alertRepositoryProvider)
          .latestForCategoryMonth(foodId, now.year, now.month);
      expect(loggedAlert, isNull);
    },
  );

  test(
    'without "No Alert Needed", the same spend would have alerted',
    () async {
      final now = DateTime.now();
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: foodId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
          maxCost: const Value(2000),
          thresholdPercent: const Value(50), // trigger = 1000
          noAlert: const Value(false),
        ),
      );
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 1500),
      );

      final summary = await _readDashboardSummary(container);
      expect(summary.activeAlerts, hasLength(1));
      expect(summary.activeAlerts.single.severity, AlertType.exceeded);
    },
  );
}
