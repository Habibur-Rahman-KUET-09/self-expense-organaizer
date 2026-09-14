import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/db/database.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:expense_tracker/providers/database_providers.dart';
import 'package:expense_tracker/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bottom nav switches between all five tabs', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    // Seed a budget so the Dashboard renders its normal summary view
    // instead of the "no budgets yet" empty state.
    final now = DateTime.now();
    final categoryId = await container
        .read(categoryRepositoryProvider)
        .add(name: 'Food');
    await container.read(budgetRepositoryProvider).upsert(
      BudgetsCompanion.insert(
        categoryId: categoryId,
        year: now.year,
        month: now.month,
        minCost: const Value(1000),
        maxCost: const Value(2000),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Starts on Dashboard.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Add Expense'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Budget Setup'), findsOneWidget);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);

    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Habits'), findsOneWidget);

    // Back to Dashboard.
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('tapping the Dashboard habit status card jumps to the Habits tab', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(db.close);

    await container.read(habitRepositoryProvider).add(
      HabitsCompanion.insert(
        name: 'Meditate',
        type: HabitType.binary,
        frequencyType: HabitFrequencyType.daily,
        startDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    expect(find.textContaining('habits done today'), findsOneWidget);

    await tester.tap(find.textContaining('habits done today'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Habits'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
