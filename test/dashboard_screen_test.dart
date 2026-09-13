import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: DashboardScreen()),
  );
}

Future<void> _teardown(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('shows the empty state when no budgets exist this month', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    expect(find.text('No budgets set for this month yet.'), findsOneWidget);

    await _teardown(tester, container);
  });

  testWidgets(
    'shows total spend, an exceeded alert, and top spending for an over-budget category',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      final now = DateTime.now();
      final categoryId = await container
          .read(categoryRepositoryProvider)
          .add(name: 'Food', colorValue: 0xFFE53935);
      await container.read(budgetRepositoryProvider).upsert(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          year: now.year,
          month: now.month,
          minCost: const Value(1000),
          maxCost: const Value(2000),
          thresholdPercent: const Value(50), // trigger = 1000
          thresholdBase: const Value(ThresholdBase.max),
        ),
      );
      await container.read(expenseRepositoryProvider).add(
        ExpensesCompanion.insert(categoryId: categoryId, date: now, amount: 1500),
      );

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('৳1,500'), findsOneWidget);
      // Total Budget is Min-only by design (Max never enters), so it's
      // 1000 here even though the category's Max is 2000.
      expect(find.textContaining('of ৳1,000 budgeted'), findsOneWidget);
      expect(find.textContaining('Daily allowance:'), findsOneWidget);

      // actual (1500) is 150% of the trigger value (1000) -> exceeded.
      expect(find.text('Active Alerts'), findsOneWidget);
      expect(find.text('Food — Threshold exceeded'), findsOneWidget);

      expect(find.text('Top Spending Categories'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('75%'), findsOneWidget); // 1500 / 2000 max

      // The Alert log should have recorded this (FR-4.3).
      final alert = await container
          .read(alertRepositoryProvider)
          .latestForCategoryMonth(categoryId, now.year, now.month);
      expect(alert?.type, AlertType.exceeded);

      await _teardown(tester, container);
    },
  );

  testWidgets(
    'shows a habit status card only when a habit is due today, independent of budgets',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(db.close);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      // No habits yet — the card doesn't clutter the empty-budgets state.
      expect(find.textContaining('habits done today'), findsNothing);

      final habitId = await container.read(habitRepositoryProvider).add(
        HabitsCompanion.insert(
          name: 'Meditate',
          type: HabitType.binary,
          frequencyType: HabitFrequencyType.daily,
          startDate: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0 / 1 habits done today'), findsOneWidget);

      await container
          .read(habitLogRepositoryProvider)
          .logDay(habitId: habitId, date: DateTime.now());
      await tester.pumpAndSettle();

      expect(find.textContaining('1 / 1 habits done today'), findsOneWidget);

      await _teardown(tester, container);
    },
  );

  testWidgets('the backup menu is grouped into Expense Tracker and Habit sections', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(container));
    await tester.pumpAndSettle();

    // Only open the menu — actually selecting an item would hit
    // share_plus's platform channel, which isn't mocked in this test
    // environment.
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(find.text('Expense Tracker'), findsOneWidget);
    expect(find.text('Export full backup (JSON)'), findsOneWidget);
    expect(find.text('Export expenses (CSV)'), findsOneWidget);
    expect(find.text('Import backup (JSON)'), findsOneWidget);
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Export habit backup (JSON)'), findsOneWidget);
    expect(find.text('Import habit backup (JSON)'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10)); // dismiss the menu
    await tester.pumpAndSettle();

    await _teardown(tester, container);
  });
}
