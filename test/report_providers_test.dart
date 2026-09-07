import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/providers/report_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('periodCategoryBreakdownProvider groups spend by category (FR-6.2)', () async {
    final now = DateTime.now();
    final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
    final transportId = await container
        .read(categoryRepositoryProvider)
        .add(name: 'Transport');
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 200),
    );
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 100),
    );
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: transportId, date: now, amount: 50),
    );

    final breakdown = await container.read(
      periodCategoryBreakdownProvider((period: ReportPeriod.month, offset: 0)).future,
    );

    expect(breakdown[foodId], 300);
    expect(breakdown[transportId], 50);
  });

  test('periodTrendProvider returns one total per period, oldest first', () async {
    final now = DateTime.now();
    final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 500),
    );

    final trend = await container.read(
      periodTrendProvider((period: ReportPeriod.month, count: 3, categoryId: null)).future,
    );

    expect(trend.length, 3);
    expect(trend.last, 500); // current month, at the end of the list
    expect(trend[0], 0); // two months ago, nothing logged
  });

  test('periodTrendProvider filters to one category when given', () async {
    final now = DateTime.now();
    final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');
    final transportId = await container
        .read(categoryRepositoryProvider)
        .add(name: 'Transport');
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 500),
    );
    await container.read(expenseRepositoryProvider).add(
      ExpensesCompanion.insert(categoryId: transportId, date: now, amount: 999),
    );

    final trend = await container.read(
      periodTrendProvider((period: ReportPeriod.month, count: 1, categoryId: foodId)).future,
    );

    expect(trend, [500]);
  });

  test(
    'periodProjectionProvider averages the 3 completed periods before now, excluding the current one',
    () async {
      final now = DateTime.now();
      final foodId = await container.read(categoryRepositoryProvider).add(name: 'Food');

      // 3 completed months back: 300, 300, 300. Current (in-progress) month
      // gets a huge value that must NOT affect the projection.
      for (var monthsAgo = 3; monthsAgo >= 1; monthsAgo--) {
        final date = DateTime(now.year, now.month - monthsAgo, 15);
        await container.read(expenseRepositoryProvider).add(
          ExpensesCompanion.insert(categoryId: foodId, date: date, amount: 300),
        );
      }
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: foodId, date: now, amount: 999999),
      );

      final projection = await container.read(
        periodProjectionProvider((period: ReportPeriod.month, categoryId: foodId)).future,
      );

      // No budget set, so maxBudget is 0 -> no overspend adjustment ->
      // projected == plain average of the 3 completed months.
      expect(projection.projected, 300);
    },
  );
}
